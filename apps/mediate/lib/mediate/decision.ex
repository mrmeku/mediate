defmodule Mediate.Decision do
  @moduledoc "The stamped verdict: what the library said, when, from what state, under which policy. It is the value the mediated repo accepts under `authorized_by:`."

  alias Mediate.Verdict

  @effects [:allow, :deny, :filter]

  @enforce_keys [
    :id,
    :subject,
    :resource,
    :action,
    :effect,
    :reason,
    :engine,
    :policy_version,
    :correlation_id,
    :decided_at
  ]
  defstruct @enforce_keys

  @typedoc "`:filter` is the effect of a `filter` decision, whose rule narrows rather than allows."
  @type effect :: :allow | :deny | :filter

  @typedoc "`policy_version` is `nil` where the engine names no version for the verdict."
  @type t :: %__MODULE__{
          id: Mediate.Id.t(),
          subject: Mediate.subject(),
          resource: Mediate.resource(),
          action: atom(),
          effect: effect(),
          reason: Verdict.reason(),
          engine: module(),
          policy_version: Mediate.PolicyRelease.policy_version() | nil,
          correlation_id: Mediate.Id.t(),
          decided_at: DateTime.t()
        }

  @doc "The three effects."
  @spec effects() :: [effect()]
  def effects, do: @effects
end
