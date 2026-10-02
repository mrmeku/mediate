defmodule Mediate.Dev.WordsTest do
  @moduledoc """
  The gate of `docs/naming.md` under "The gate", run over the tree. The
  test reads the command from the document and runs nothing else: the
  pattern between the quotes is the words the ledger bans, and the paths
  after it are the files the ban covers. So the document and the test hold
  one list, and a word added to the command is a word this test refuses.
  """

  use ExUnit.Case, async: true

  @umbrella Path.expand("../../..", __DIR__)
  @ledger Path.join(@umbrella, "docs/naming.md")

  test "no file the gate covers carries a word the ledger bans" do
    {pattern, paths, excluded} = gate()

    hits =
      for path <- paths,
          file <- files(path),
          Path.basename(file) not in excluded,
          {text, number} <- lines(file),
          String.match?(text, pattern) do
        "#{Path.relative_to(file, @umbrella)}:#{number}: #{text}"
      end

    assert hits == [], "the gate of docs/naming.md found a banned word:\n" <> Enum.join(hits, "\n")
  end

  defp gate do
    command =
      @ledger
      |> File.read!()
      |> String.split("\n")
      |> Enum.find(&String.starts_with?(&1, "grep "))

    [_whole, pattern] = Regex.run(~r/"([^"]+)"/, command)
    [_whole, rest] = Regex.run(~r/"[^"]+" (.+?);/, command)
    excluded = List.flatten(Regex.scan(~r/--exclude=(\S+)/, command, capture: :all_but_first))

    {Regex.compile!(pattern, "i"), String.split(rest), excluded}
  end

  defp files(path) do
    @umbrella
    |> Path.join(path)
    |> Path.wildcard()
    |> Enum.flat_map(&under/1)
  end

  defp under(path) do
    if File.dir?(path) do
      path
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.reject(&File.dir?/1)
    else
      [path]
    end
  end

  defp lines(file) do
    file
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
  end
end
