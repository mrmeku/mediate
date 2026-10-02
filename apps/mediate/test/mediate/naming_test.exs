defmodule Mediate.NamingTest do
  @moduledoc """
  Every public name of this package is a row of `docs/naming.md`. The
  surface comes from `Mediate.Dev.Surface`, which `mix mediate.surface`
  prints, and the words come from the ledger's tables: every backticked
  token in a cell of any column but Rejected. A name that is not a word
  fails here, so a new name and its row land in one commit, as
  `CONTRIBUTING.md` under "The rules" asks.
  """

  use ExUnit.Case, async: true

  alias Mediate.Dev.Surface

  @moduletag :freeze

  @ledger Path.expand("../../../../docs/naming.md", __DIR__)

  setup_all do
    %{surface: Surface.of(:mediate), words: words()}
  end

  test "every public module is a ledger word", %{surface: surface, words: words} do
    assert_words(Enum.map(surface.modules, &inspect/1), words)
  end

  test "every public function is a ledger word", %{surface: surface, words: words} do
    assert_words(Enum.map(surface.functions, fn {_module, name, _arity, _spec} -> unmarked(name) end), words)
  end

  test "every struct field is a ledger word", %{surface: surface, words: words} do
    assert_words(Enum.flat_map(surface.fields, fn {_module, fields} -> Enum.map(fields, &Atom.to_string/1) end), words)
  end

  test "every atom a public type offers is a ledger word", %{surface: surface, words: words} do
    assert_words(
      Enum.flat_map(surface.atoms, fn {_module, _type, atoms} -> Enum.map(atoms, &Atom.to_string/1) end),
      words
    )
  end

  test "every option key is a ledger word", %{surface: surface, words: words} do
    assert_words(Enum.flat_map(surface.options, fn {_module, keys} -> Enum.map(keys, &Atom.to_string/1) end), words)
  end

  test "every event name and event key is a ledger word", %{surface: surface, words: words} do
    names = Enum.flat_map(surface.events, fn {_module, event, _keys} -> Enum.map(event, &Atom.to_string/1) end)
    keys = Enum.flat_map(surface.events, fn {_module, _event, keys} -> Enum.map(keys, &Atom.to_string/1) end)
    assert_words(names ++ keys, words)
  end

  # The writing gate keeps the mark out of the ledger, so a row says
  # "`boot/1` with the mark" and the test drops it.
  defp unmarked(name), do: String.trim_trailing(Atom.to_string(name), "!")

  defp assert_words(names, words) do
    missing =
      names
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(words, &1))
      |> Enum.sort()

    assert missing == [], "not in docs/naming.md: #{Enum.join(missing, ", ")}"
  end

  # Every backticked token in a table cell of any column but Rejected,
  # broken into the names it carries: `Mediate.Test.with_config/1,2` gives
  # the module, the function, and the bare name, and `{type, :all}` gives
  # each atom in it.
  defp words do
    @ledger
    |> File.read!()
    |> tables()
    |> Enum.flat_map(fn {header, rows} -> Enum.flat_map(rows, &kept(&1, header)) end)
    |> Enum.flat_map(&names_in/1)
    |> MapSet.new()
  end

  # Each table as its header and its rows. A table ends where a row's cell
  # count differs from the header's, and the dashed row is no row.
  defp tables(text) do
    text
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "| "))
    |> Enum.map(&cells/1)
    |> Enum.chunk_while(nil, &chunk_table/2, &{:cont, &1})
  end

  defp chunk_table(cells, nil), do: {:cont, {cells, []}}
  defp chunk_table(["---" | _rest], table), do: {:cont, table}

  defp chunk_table(cells, {header, rows}) when length(cells) != length(header) do
    {:cont, {header, rows}, {cells, []}}
  end

  defp chunk_table(cells, {header, rows}), do: {:cont, {header, [cells | rows]}}

  defp kept(row, header) do
    row
    |> Enum.zip(header)
    |> Enum.reject(fn {_cell, column} -> column == "Rejected" end)
    |> Enum.flat_map(fn {cell, _column} -> Regex.scan(~r/`([^`]+)`/, cell, capture: :all_but_first) end)
    |> List.flatten()
  end

  defp names_in(token) do
    ~r/[A-Za-z][A-Za-z0-9_.]*[?!]?/
    |> Regex.scan(token)
    |> List.flatten()
    |> Enum.flat_map(fn name -> [name, List.last(String.split(name, "."))] end)
    |> Enum.map(&String.trim_trailing(&1, "."))
  end

  defp cells(line) do
    line
    |> String.split("|")
    |> Enum.drop(1)
    |> Enum.drop(-1)
    |> Enum.map(&String.trim/1)
  end
end
