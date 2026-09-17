defmodule Mediate.Answer do
  @moduledoc """
  What a decider answers for one subject, operation, and object. It holds
  the verdict, the reason in one word, the version of the rules that gave
  it, and `meta`.

  `meta` belongs to the decider. What only one decider can say travels
  there, so the reason stays a word every decider shares. A decider that
  sets one of these keys gives it this value:

  | Key | Value |
  |---|---|
  | `:rule` | The rule, clause, policy, or relation the verdict came from |
  | `:matched` | The rules, clauses, or path an explanation lists |
  | `:detail` | The engine's own text, where the reason is `:engine_unreachable` |
  | `:kind` | The subject kind the port does not know |
  """

  @reasons [
    :allowed,
    :deny_by_default,
    :rule_denied,
    :engine_unreachable,
    :missing_fact,
    :unknown_operation,
    :unknown_subject_kind
  ]

  @enforce_keys [:verdict, :reason]
  defstruct [:verdict, :reason, version: nil, meta: %{}]

  @typedoc "What the rule said about the request."
  @type verdict :: :allow | :deny

  @typedoc "Why the verdict is what it is, in a form a record carries without an attribute value."
  @type reason ::
          :allowed
          | :deny_by_default
          | :rule_denied
          | :engine_unreachable
          | :missing_fact
          | :unknown_operation
          | :unknown_subject_kind

  @typedoc "One answer: the verdict, why, the policy version that decided, and whatever the adapter puts in `meta`."
  @type t :: %__MODULE__{verdict: verdict(), reason: reason(), version: String.t() | nil, meta: map()}

  @doc "The reasons, in the order the type lists them."
  @spec reasons() :: [reason()]
  def reasons, do: @reasons
end
