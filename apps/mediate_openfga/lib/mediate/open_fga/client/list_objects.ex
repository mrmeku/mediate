defmodule Mediate.OpenFGA.Client.ListObjects do
  @moduledoc """
  Every object of one type the user holds one relation on. The answer is
  a list of objects. That is what makes a filter one query on the
  deployment's side: the ids go into the rule the engine hands back.

  The server limits how many objects it answers with. So a caller that
  cares whether the list is whole compares its length against the limit.
  """

  alias Mediate.OpenFGA.Consistency

  @enforce_keys [:user, :relation, :type]
  defstruct [:user, :relation, :type, :model_id, context: %{}, consistency: :unspecified]

  @typedoc "One list-objects request."
  @type t :: %__MODULE__{
          user: String.t(),
          relation: String.t(),
          type: String.t(),
          model_id: String.t() | nil,
          context: %{String.t() => term()},
          consistency: Consistency.t()
        }
end
