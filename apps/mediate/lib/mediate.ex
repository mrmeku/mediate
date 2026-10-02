defmodule Mediate do
  @moduledoc """
  The one place an application asks whether a subject can perform an action
  on a resource. The words are `docs/naming.md`'s: subject, action,
  resource, and context.

  - `authorize/4` when the call reaches the repo: it answers the decision
    the mediated repo accepts under `authorized_by:`.
  - `authorized?/4` when a branch needs a yes or no and reaches no repo.
  - `filter/4` when a query covers a whole type: it answers a `dynamic` the
    query carries, which can only narrow, and a decision whose resource is
    `{type, :all}`.
  - `review/5` when a reviewer asks who can do what today: one `filter` per
    subject under the reviewer's correlation id.

  The library resolves the configuration and builds the context from the
  caller's map and the clock. It asks the engine. It fails closed on an
  engine error or on an exception the engine raised. It stamps a
  `Mediate.Decision` and publishes it.

  Every decision publishes one `[:mediate, :decision]` event.
  [Events](events.html) under "Decision" has the payload. A decision is a
  read, so it has no transaction. The one measurement is
  `duration_microseconds`.

  The library denies a subject whose kind it does not know before it asks
  the engine. The event of that denial says `:unknown` as the kind.

  This module is the top-layer boundary. Everything under `Mediate` that is
  not `Mediate.Test` belongs to it. It can reach `Ecto` and `NimbleOptions`.
  It reaches nothing from `ecto_sql` or `postgrex`, because a decision does
  not query.
  """

  use Boundary,
    deps: [Ecto, NimbleOptions],
    check: [apps: [:ecto_sql, :postgrex]],
    exports: [
      Config,
      Decision,
      Engine,
      Error,
      Exemption,
      Id,
      IdentityWrite,
      Infrastructure.Enforcement,
      Infrastructure.Overrides,
      Infrastructure.Surface,
      PolicyRelease,
      Repo,
      ResourceRead,
      Schema,
      Schema.Fact,
      Schema.Grant,
      Verdict
    ]

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Config
  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.Id
  alias Mediate.Verdict

  @options NimbleOptions.new!(
             context: [type: {:map, :atom, :any}, default: %{}, doc: "The facts only the caller knows, by name."],
             correlation_id: [type: :string, doc: "The id every record of this unit of work carries; fresh when absent."]
           )

  @kinds [:user, :service, :privileged]
  @event [:mediate, :decision]

  @typedoc """
  What the subject asks about: a resource type and an id. A decision over a
  whole type, which `filter/4` makes, carries `:all` for the id.
  """
  @type resource :: {atom(), Id.t() | :all}

  @typedoc """
  Under what conditions the subject asks: the facts only the caller knows,
  by name, with `now` from the configured clock beside them. The library
  stamps `now`, so an engine reads the moment of the request from the
  context rather than from a clock of its own.
  """
  @type context :: %{required(:now) => DateTime.t(), optional(atom()) => term()}

  @typedoc "A person, software that acts alone, or a person who can change the system."
  @type subject_kind :: :user | :service | :privileged

  @typedoc """
  Who asks: a kind and an account id. The kind travels with every decision
  record. The library refuses a kind it does not know.
  """
  @type subject :: {subject_kind(), Id.t()}

  @typedoc "The options every one of the four functions takes."
  @type options :: [context: %{atom() => term()}, correlation_id: Id.t()]

  @typedoc "A review's answer per subject: the rule over the resource type and the decision it runs under."
  @type reviewed :: %{subject() => {Ecto.Query.dynamic_expr(), Decision.t()}}

  @doc "The three subject kinds the library knows."
  @spec subject_kinds() :: [subject_kind()]
  def subject_kinds, do: @kinds

  @doc "The telemetry event each decision publishes, which is what a consumer attaches to."
  @spec event() :: [atom()]
  def event, do: @event

  @doc "The schema of the options."
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @options

  @doc "Decide for one resource. The decision is the record and the value the mediated repo takes."
  @spec authorize(subject(), atom(), resource(), options()) :: {:ok, Decision.t()} | {:error, Error.t()}
  def authorize({_kind, _account} = subject, action, {_type, _id} = resource, opts \\ [])
      when is_atom(action) and is_list(opts) do
    {decision, verdict} = one(subject, action, resource, opts)

    case decision.effect do
      :allow -> {:ok, decision}
      :deny -> {:error, not_authorized(subject, action, resource, verdict)}
    end
  end

  @doc "Decide for one resource and answer yes or no alone. An engine that fails answers `false`."
  @spec authorized?(subject(), atom(), resource(), options()) :: boolean()
  def authorized?({_kind, _account} = subject, action, {_type, _id} = resource, opts \\ [])
      when is_atom(action) and is_list(opts) do
    {decision, _verdict} = one(subject, action, resource, opts)
    decision.effect == :allow
  end

  @doc """
  The rule a row of the resource type must satisfy, with the decision the
  query carries. Under a denied precondition or a failed engine the rule is
  one no row satisfies and the effect is `:deny`.
  """
  @spec filter(subject(), atom(), atom(), options()) :: {Ecto.Query.dynamic_expr(), Decision.t()}
  def filter({_kind, _account} = subject, action, resource_type, opts \\ [])
      when is_atom(action) and is_atom(resource_type) and is_list(opts) do
    filtered(prepare(subject, opts), subject, action, resource_type)
  end

  @doc """
  Who can do what: `filter` per subject over a resource type, under one
  correlation id. Each subject's decision is its own record. A query the
  reviewer runs under that decision enters the log under that subject. The
  reviewer's own decision over the type is the record of the review.
  """
  @spec review(subject(), [subject()], atom(), atom(), options()) :: reviewed()
  def review({_kind, _account} = reviewer, subjects, action, resource_type, opts \\ [])
      when is_list(subjects) and is_atom(action) and is_atom(resource_type) and is_list(opts) do
    call = prepare(reviewer, opts)

    decided(call, reviewer, action, {resource_type, :all}, fn ->
      reviewed = Map.new(subjects, &{&1, filtered(call, &1, action, resource_type)})
      decision = stamp(call, reviewer, action, {resource_type, :all}, review_verdict(), :filter)
      {reviewed, decision, %{}}
    end)
  end

  defp review_verdict, do: %Verdict{effect: :allow, reason: :rule_allowed, meta: %{rule: "review"}}

  # One resource: authorize and authorized? share this. The verdict travels
  # beside the decision, because a denial names what the record does not
  # carry.
  defp one(subject, action, {_type, _id} = resource, opts) do
    call = prepare(subject, opts)

    decided(call, subject, action, resource, fn ->
      verdict = ask(call, subject, action, resource)
      decision = stamp(call, subject, action, resource, verdict, verdict.effect)
      {{decision, verdict}, decision, said(verdict)}
    end)
  end

  # One type for one subject: filter and each subject of a review share
  # this. The event carries the rule in the resource's place.
  defp filtered(call, subject, action, type) do
    call = %{call | kind: kind(subject)}

    decided(call, subject, action, {type, :all}, fn ->
      {rule, verdict} = rule(call, subject, action, type)
      decision = stamp(call, subject, action, {type, :all}, verdict, filter_effect(verdict))
      {{rule, decision}, decision, Map.put(said(verdict), :resource, rule)}
    end)
  end

  # Everything a call needs, resolved once.
  defp prepare({_kind, _account} = subject, opts) do
    validated = NimbleOptions.validate!(opts, @options)
    config = config!()
    {engine, options} = Config.engine(config)

    %{
      config: config,
      engine: engine,
      options: options,
      kind: kind(subject),
      given: validated[:context],
      context: Map.put(validated[:context], :now, config.clock.()),
      correlation_id: Keyword.get_lazy(validated, :correlation_id, &Id.new/0)
    }
  end

  defp kind({kind, _account}) when kind in @kinds, do: kind
  defp kind({_kind, _account}), do: :unknown

  # The engine's verdict for one resource, or the denial the library gives
  # in its place. The library denies an unknown subject kind before it asks
  # the engine, and an engine failure after.
  defp ask(%{kind: :unknown}, subject, _action, _resource), do: unknown_kind(subject)

  defp ask(call, subject, action, resource) do
    case asked(call, :authorize, subject, action, resource) do
      {:ok, %Verdict{} = verdict} -> verdict
      {:error, %Error{reason: :engine_failed} = error, exception} -> closed(error, exception)
    end
  end

  # The engine's verdict, or the error the library answers in its place.
  # The error is the failure the engine reported or the exception it
  # raised. The third element carries the exception, so the event names
  # what broke. An engine that raises closes the door and never reaches the
  # caller. So no engine carries a rescue clause for the driver underneath
  # it.
  defp asked(call, function, subject, action, resource) do
    case answered(call, function, subject, action, resource) do
      {:ok, verdict} -> {:ok, verdict}
      {:error, %Error{} = error} -> {:error, error, nil}
    end
  rescue
    exception -> {:error, raised(call.engine, function, exception), exception}
  end

  defp answered(%{engine: engine} = call, :authorize, subject, action, resource) do
    engine.authorize(subject, action, resource, call.context, call.options)
  end

  defp answered(%{engine: engine} = call, :filter, subject, action, type) do
    engine.filter(subject, action, type, call.context, call.options)
  end

  defp rule(%{kind: :unknown}, subject, _action, _type), do: {refused(), unknown_kind(subject)}

  defp rule(call, subject, action, type) do
    case asked(call, :filter, subject, action, type) do
      {:ok, {rule, %Verdict{effect: :allow} = verdict}} -> {rule, verdict}
      {:ok, {_rule, %Verdict{effect: :deny} = verdict}} -> {refused(), verdict}
      {:error, %Error{reason: :engine_failed} = error, exception} -> {refused(), closed(error, exception)}
    end
  end

  defp refused, do: dynamic([_row], false)

  defp filter_effect(%Verdict{effect: :allow}), do: :filter
  defp filter_effect(%Verdict{effect: :deny}), do: :deny

  # The door closed: the verdict carries what broke, which is the exception
  # the engine raised, or the error it answered with when it raised none.
  defp closed(%Error{reason: :engine_failed, message: message} = error, nil) do
    %Verdict{effect: :deny, reason: :engine_failed, meta: %{message: message, exception: error}}
  end

  defp closed(%Error{reason: :engine_failed, message: message}, exception) do
    %Verdict{effect: :deny, reason: :engine_failed, meta: %{message: message, exception: exception}}
  end

  defp raised(engine, function, exception) do
    %Error{
      reason: :engine_failed,
      message: "#{inspect(engine)} raised during #{function}: #{Exception.message(exception)}"
    }
  end

  # What the event says beyond the effect: what broke, where the verdict
  # closed the door in the engine's place.
  defp said(%Verdict{meta: %{exception: exception}}), do: %{exception: exception}
  defp said(%Verdict{}), do: %{}

  defp unknown_kind({kind, _account}) do
    %Verdict{effect: :deny, reason: :subject_kind_unknown, meta: %{subject_kind: kind}}
  end

  defp stamp(call, subject, action, resource, %Verdict{} = verdict, effect) do
    %Decision{
      id: Id.new(),
      subject: subject,
      resource: resource,
      action: action,
      effect: effect,
      reason: verdict.reason,
      engine: call.engine,
      policy_version: verdict.policy_version,
      correlation_id: call.correlation_id,
      decided_at: call.context.now
    }
  end

  # One decision, published after the call. `fun` returns the call's
  # result, the decision, and what the call knows only afterwards. For a
  # filter call that is the rule in the resource's place.
  defp decided(call, subject, action, resource, fun) do
    started = System.monotonic_time()

    try do
      {result, decision, extra} = fun.()
      publish(call, subject, action, resource, started, Map.merge(extra, effect_out(decision)))
      result
    rescue
      exception ->
        publish(call, subject, action, resource, started, %{exception: exception})
        reraise exception, __STACKTRACE__
    end
  end

  defp publish(call, subject, action, resource, started, said) do
    duration = System.convert_time_unit(System.monotonic_time() - started, :native, :microsecond)

    metadata =
      Map.merge(
        %{
          subject: subject,
          subject_kind: call.kind,
          action: action,
          resource: resource,
          effect: nil,
          reason: nil,
          engine: call.engine,
          policy_version: nil,
          context: call.given,
          exception: nil,
          decision_id: nil,
          decided_at: call.context.now,
          correlation_id: call.correlation_id
        },
        said
      )

    :telemetry.execute(@event, %{duration_microseconds: duration}, metadata)
  end

  defp effect_out(%Decision{} = decision) do
    %{
      effect: decision.effect,
      reason: decision.reason,
      policy_version: decision.policy_version,
      decision_id: decision.id
    }
  end

  defp not_authorized(subject, action, resource, %Verdict{} = verdict) do
    Error.denied(subject, action, resource, verdict.reason, Map.get(verdict.meta, :message))
  end

  defp config! do
    case Config.resolve() do
      {:ok, config} -> config
      {:error, error} -> raise error
    end
  end
end
