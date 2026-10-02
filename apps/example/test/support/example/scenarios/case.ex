defmodule Example.Scenarios.Case do
  @moduledoc """
  The `scenario` macro: a `test` named by the scenario's id and sentence,
  and tagged with them. The tags are the id, the clause the declaration
  says it proves, and the controls the document cites for it. The table
  carries the controls and the declaration does not, so a control id lives
  in one place. The macro holds every declaration to
  `Example.Scenarios.Table` when the module compiles, so a scenario cannot
  drift from the table.

  What a deployment enforces each clause with is prose in that deployment's
  README, a table a person writes and keeps. Nothing here reads it, and a
  scenario runs under every deployment.

      use Example.Scenarios.Case

      scenario "enf-01", "An Account with a Membership in a Repository's Project reads it", clause: :c1 do
        ...
      end
  """

  alias Example.Scenarios.Case
  alias Example.Scenarios.Row
  alias Example.Scenarios.Table

  @doc false
  defmacro __using__(opts) do
    async = Keyword.get(opts, :async, true)

    quote do
      use ExUnit.Case, async: unquote(async)

      import Case, only: [scenario: 4]
    end
  end

  @doc "Declare one scenario. The module documentation has the form."
  defmacro scenario(id, sentence, opts, do: block) do
    quote bind_quoted: [id: id, sentence: sentence, opts: opts], unquote: true do
      for {key, value} <- Case.__tags__(id, sentence, opts) do
        @tag [{key, value}]
      end

      test Case.__name__(id, sentence) do
        unquote(block)
      end
    end
  end

  @doc false
  @spec __name__(String.t(), String.t()) :: String.t()
  def __name__(id, sentence) when is_binary(id) and is_binary(sentence), do: id <> " " <> sentence

  @doc false
  @spec __tags__(String.t(), String.t(), keyword()) :: keyword()
  def __tags__(id, sentence, opts) when is_binary(id) and is_binary(sentence) and is_list(opts) do
    scenario = fetch!(id)
    check_sentence!(scenario, sentence)
    clause = check_clause!(scenario, Keyword.fetch!(opts, :clause))

    [scenario: id, clause: clause, controls: scenario.controls]
  end

  defp fetch!(id) do
    case Table.fetch(id) do
      {:ok, %Row{} = scenario} -> scenario
      :error -> raise ArgumentError, "no scenario #{inspect(id)} in the table"
    end
  end

  defp check_sentence!(%Row{id: id, sentence: expected}, sentence) do
    if sentence == expected do
      :ok
    else
      raise ArgumentError, "scenario #{id} reads #{inspect(expected)} in the table, got: #{inspect(sentence)}"
    end
  end

  defp check_clause!(%Row{id: id, clauses: clauses}, clause) do
    if clause in clauses do
      clause
    else
      raise ArgumentError, "scenario #{id} proves #{inspect(clauses)}, got clause: #{inspect(clause)}"
    end
  end
end
