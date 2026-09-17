defmodule Mediate.Fga.Client.Check do
  @moduledoc """
  One question: does this tuple hold. The tuple key names the user, the
  relation, and the object the question is about. The context is what the
  server evaluates the model's conditions against, so the environment of a
  request goes there. The model id pins which model answers. So a decision
  runs under a version and not under whatever is current.
  """

  alias Mediate.Fga.Consistency
  alias Mediate.Fga.TupleKey

  @enforce_keys [:tuple_key]
  defstruct [:tuple_key, :model, context: %{}, consistency: :unspecified]

  @typedoc "One check request."
  @type t :: %__MODULE__{
          tuple_key: TupleKey.t(),
          model: String.t() | nil,
          context: %{String.t() => term()},
          consistency: Consistency.t()
        }
end
