defmodule Mediate.Engine do
  @moduledoc """
  The contract every engine implements. The library calls each callback
  with a subject, an action, a resource or a resource type, the context,
  and the engine's validated options. The engine answers and never raises
  on the request path. `around_query/3`, `options_schema/0`, and `sync/0`
  are optional. The library and the mediated repo check at runtime whether
  the engine exports them, so one build serves every engine. What produced
  a verdict travels on the verdict's `meta`, where the engine can say.

  Two declarations hold for an engine in any domain. `filter_limit/0` is
  the largest number of resources `filter` can enumerate, or `:infinity`
  where the rule is a query the database runs. `sync/0` says whether the
  engine has state of its own to bring into step. An engine that reads the
  application's own tables has none.

  An engine is domain-free. It names no schema and no rule of the
  application, and the coverage test each engine package carries holds it
  to that.
  """

  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.Verdict

  @typedoc "The options the library hands the engine, unchanged."
  @type options :: keyword()
  @typedoc "What a callback returns when it cannot answer."
  @type failure :: {:error, Error.t()}

  @typedoc "What `filter/5` answers: the rule as a dynamic, and the verdict that goes with it."
  @type filtered :: {Ecto.Query.dynamic_expr(), Verdict.t()}

  @doc "Decide for one resource. The library records it, whether the caller asked `authorize` or `authorized?`."
  @callback authorize(Mediate.subject(), atom(), Mediate.resource(), Mediate.context(), options()) ::
              {:ok, Verdict.t()} | failure()

  @doc "The rule that narrows a query over a resource type to what the subject can see."
  @callback filter(Mediate.subject(), atom(), atom(), Mediate.context(), options()) ::
              {:ok, filtered()} | failure()

  @doc """
  Wrap a mediated call. The arguments are the query or changeset, the
  decision in force, and the zero-arity function that runs the call. An
  engine that needs session state at execution, such as row-level security
  settings, sets it here and then calls the function. Every other engine
  leaves this undefined, and the mediated repo calls the function directly.
  """
  @callback around_query(Ecto.Query.t() | Ecto.Changeset.t(), Decision.t(), (-> term())) :: term()

  @doc "The schema for the engine's entry in `Mediate.Config`. When absent, the entry must be the bare module."
  @callback options_schema() :: NimbleOptions.t()

  @doc "The largest number of resources `filter` can enumerate, or `:infinity`."
  @callback filter_limit() :: pos_integer() | :infinity

  @doc """
  Bring the state the engine keeps of its own into step with the
  application's tables. Answer `:ok` when nothing is outstanding. Answer
  `:stateless` for an engine that keeps no state, which is what an engine
  that leaves this callback undefined says. A caller that has written facts
  and is about to ask about them syncs first. `Mediate.Test.sync/0` is that
  caller in the suite.

  A caller syncs in place of a wait. An application in production has a
  process that brings the same state into step on its own interval. Nothing
  on the request path calls this.
  """
  @callback sync() :: :ok | :stateless | {:error, Error.t()}

  @optional_callbacks around_query: 3, options_schema: 0, sync: 0
end
