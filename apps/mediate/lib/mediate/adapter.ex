defmodule Mediate.Adapter do
  @moduledoc """
  The contract every adapter implements. The port calls each callback with
  a subject, an operation, an object or an object type, the environment,
  and the adapter's validated options. The adapter answers and never raises
  on the request path. `around_query/3`, `options_schema/0`, and `settle/0`
  are optional. The port and the seam check at runtime whether the adapter
  exports them, so one build serves every adapter. What produced an answer
  travels on the answer's `meta`, where the adapter can say.

  Two declarations hold for an adapter in any domain. `scope_cap/0` is the
  cap on the number of objects `scope` can return, or `:none` where the
  rule is a query the database runs. `settle/0` says whether the adapter
  has state of its own to settle. An adapter that reads the application's
  own tables has none.

  An adapter is domain-free. It names no schema and no rule of the
  application, and the coverage test each adapter package carries holds it
  to that.
  """

  alias Mediate.Answer
  alias Mediate.Decision
  alias Mediate.Error

  @typedoc "The options the port hands the adapter, unchanged."
  @type options :: keyword()
  @typedoc "What a callback returns when it cannot answer."
  @type failure :: {:error, Error.t()}

  @typedoc "What `scope/5` answers: the rule as a dynamic, and the answer that goes with it."
  @type scoped :: {Ecto.Query.dynamic_expr(), Answer.t()}

  @doc "Decide for one object. The port records it, whether the caller asked `authorize` or `check`."
  @callback decide(Mediate.subject(), atom(), Mediate.object(), Mediate.environment(), options()) ::
              {:ok, Answer.t()} | failure()

  @doc "The rule that narrows a query over an object type to what the subject can see."
  @callback scope(Mediate.subject(), atom(), atom(), Mediate.environment(), options()) ::
              {:ok, scoped()} | failure()

  @doc """
  Wrap a mediated call. The arguments are the query or changeset, the
  decision in force, and the zero-arity function that runs the call. An
  adapter that needs session state at execution, such as row-level security
  settings, sets it here and then calls the function. Every other adapter
  leaves this undefined, and the seam calls the function directly.
  """
  @callback around_query(Ecto.Query.t() | Ecto.Changeset.t(), Decision.t(), (-> term())) :: term()

  @doc "The schema for the adapter's entry in `Mediate.Config`. When absent, the entry must be the bare module."
  @callback options_schema() :: NimbleOptions.t()

  @doc "The cap on objects `scope` can return, or `:none`."
  @callback scope_cap() :: pos_integer() | :none

  @doc """
  Bring the state the adapter keeps of its own into step with the
  application's tables. Answer `:ok` when nothing is outstanding. Answer
  `:none` for an adapter that keeps no state, which is what an adapter that
  leaves this callback undefined says. A caller that has written facts and
  is about to ask about them settles first. `Mediate.Test.settle/0` is that
  caller in the suite.

  A caller settles in place of a wait. An application in production has a
  process that brings the same state into step on its own interval. Nothing
  on the request path calls this.
  """
  @callback settle() :: :ok | :none | {:error, Error.t()}

  @optional_callbacks around_query: 3, options_schema: 0, settle: 0
end
