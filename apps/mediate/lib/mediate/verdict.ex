defmodule Mediate.Verdict do
  @moduledoc """
  What an engine answers for one subject, action, and resource. It holds
  the effect, the reason in one word, the version of the policy that gave
  it, and `meta`.

  `meta` belongs to the engine. What only one engine can say travels there,
  so the reason stays a word every engine shares. An engine that sets one
  of these keys gives it this value:

  | Key | Value |
  |---|---|
  | `:rule` | The rule, clause, policy, or relation the effect came from |
  | `:matched` | The rules, clauses, or path an explanation lists |
  | `:message` | The engine's own text, where the reason is `:engine_failed` |
  | `:subject_kind` | The subject kind the library does not know |
  """

  @reasons [
    :rule_allowed,
    :no_rule_matched,
    :rule_denied,
    :engine_failed,
    :fact_missing,
    :action_unknown,
    :subject_kind_unknown
  ]

  @enforce_keys [:effect, :reason]
  defstruct [:effect, :reason, policy_version: nil, meta: %{}]

  @typedoc "What the rule said about the request."
  @type effect :: :allow | :deny

  @typedoc "Why the effect is what it is, in a form a record carries without an attribute value."
  @type reason ::
          :rule_allowed
          | :no_rule_matched
          | :rule_denied
          | :engine_failed
          | :fact_missing
          | :action_unknown
          | :subject_kind_unknown

  @typedoc "One verdict: the effect, why, the policy version that decided, and whatever the engine puts in `meta`."
  @type t :: %__MODULE__{effect: effect(), reason: reason(), policy_version: String.t() | nil, meta: map()}

  @doc "The reasons, in the order the type lists them."
  @spec reasons() :: [reason()]
  def reasons, do: @reasons
end
