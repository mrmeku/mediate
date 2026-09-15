defmodule Mediate.Decision do
  @moduledoc "What the port said, when, from what state, under which rules."

  alias Mediate.Answer

  @verdicts [:allow, :deny, :scoped]

  @enforce_keys [
    :id,
    :subject,
    :object,
    :operation,
    :verdict,
    :reason,
    :adapter,
    :policy_version,
    :operation_id,
    :at
  ]
  defstruct @enforce_keys

  @typedoc "`:scoped` is the verdict of a `scope` decision, whose rule narrows rather than allows."
  @type verdict :: :allow | :deny | :scoped

  @typedoc "`policy_version` is `nil` where the adapter names no version for the answer."
  @type t :: %__MODULE__{
          id: Mediate.Id.t(),
          subject: Mediate.subject(),
          object: Mediate.object(),
          operation: atom(),
          verdict: verdict(),
          reason: Answer.reason(),
          adapter: module(),
          policy_version: Mediate.PolicyVersion.ref() | nil,
          operation_id: Mediate.Id.t(),
          at: DateTime.t()
        }

  @doc "The three verdicts."
  @spec verdicts() :: [verdict()]
  def verdicts, do: @verdicts
end
