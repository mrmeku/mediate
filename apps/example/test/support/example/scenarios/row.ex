defmodule Example.Scenarios.Row do
  @moduledoc "One row of the scenario table in `docs/example.md` under The scenarios: the id, the sentence, the group, the controls cited, and the clauses it proves."

  @enforce_keys [:id, :sentence, :group, :controls, :clauses]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          sentence: String.t(),
          group: atom(),
          controls: [String.t()],
          clauses: [atom()]
        }
end
