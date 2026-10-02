defmodule Mediate.OpenFGA.TupleKey do
  @moduledoc """
  One tuple: a user, a relation, an object, and the condition it carries.

  The first three are its triple, which is what `triple/1` answers and
  what identifies the tuple in the store. The condition is a value on it.
  So a tuple whose condition changed is the same triple with another
  context. One `Write` refuses a triple that appears in both its deletes
  and its writes (OpenFGA 1.19.0). So a change of condition takes two
  calls, the delete first. Between the two calls the store holds neither
  value.

  A user, a relation, and an object are the strings the server reads:
  `user:ann`, `reader`, `folder:1`. An object names its type before the
  colon, which is what `object_type/1` answers and what `Read` pages by.
  `to_string/1` on a tuple is the three joined by spaces, for an error
  message and a drift report.
  """

  alias Mediate.OpenFGA.Condition

  @enforce_keys [:user, :relation, :object]
  defstruct [:user, :relation, :object, condition: nil]

  @typedoc "A tuple's triple: its user, its relation, and its object."
  @type triple :: {String.t(), String.t(), String.t()}

  @typedoc "One tuple: its triple, and the condition it carries."
  @type t :: %__MODULE__{
          user: String.t(),
          relation: String.t(),
          object: String.t(),
          condition: Condition.t() | nil
        }

  @doc "The tuple's triple, without the condition it carries."
  @spec triple(t()) :: triple()
  def triple(%__MODULE__{} = tuple), do: {tuple.user, tuple.relation, tuple.object}

  @doc "The object's type, the part before the colon."
  @spec object_type(t()) :: String.t()
  def object_type(%__MODULE__{object: object}) do
    [type | _id] = String.split(object, ":", parts: 2)
    type
  end

  defimpl String.Chars do
    @spec to_string(Mediate.OpenFGA.TupleKey.t()) :: String.t()
    def to_string(tuple), do: "#{tuple.user} #{tuple.relation} #{tuple.object}"
  end
end
