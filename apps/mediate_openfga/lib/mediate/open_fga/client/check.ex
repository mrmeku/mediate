defmodule Mediate.OpenFGA.Client.Check do
  @moduledoc """
  One question: does this tuple hold. The tuple key names the user, the
  relation, and the object the question is about. The context is what the
  server evaluates the model's conditions against, so the context of a
  request goes there. The model id pins which model answers. So a
  decision runs under a version and not under whatever is current.
  """

  alias Mediate.OpenFGA.Consistency
  alias Mediate.OpenFGA.TupleKey

  @enforce_keys [:tuple_key]
  defstruct [:tuple_key, :model_id, context: %{}, consistency: :unspecified]

  @typedoc "One check request."
  @type t :: %__MODULE__{
          tuple_key: TupleKey.t(),
          model_id: String.t() | nil,
          context: %{String.t() => term()},
          consistency: Consistency.t()
        }
end
