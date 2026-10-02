defmodule Mediate.Conformance.Procedure do
  @moduledoc """
  The procedures of the engine case: one function per engine requirement,
  named by the requirement's id with `_` for `-`, plus the two tests
  beside the table. Each is a function of the test context and the
  generated values. So the case stays a list of names, and the assertions
  live where a reader can read them. Nothing here names a schema, a
  subject, or an action. A procedure that gets a world reaches its
  `Mediate.Conformance.World` through the struct. A procedure that needs a
  fixed one asks the module the case got.

  Every writer of a world calls `tick/0` first. So the stubbed clock moves
  forward through a test, and two writes never share a moment.

  This module carries the access-control procedures, `ac3`, the revocation
  latency, `ac2-05`, and the grant write budget. It also carries what
  every procedure shares:

  - the install of a world
  - the grantee of the granted world
  - the read of the decision events a call published

  `Procedure.Accounts` has the account procedures. `Procedure.Audit` has
  the audit procedures. `Procedure.Change` has the change-management
  procedures.
  """

  import Ecto.Query, only: [where: 2]
  import ExUnit.Assertions

  alias Mediate.Conformance.World
  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.Schema
  alias Mediate.Test
  alias Mediate.Test.Clock

  @base ~U[2026-01-01 00:00:00Z]
  @tick_key {__MODULE__, :tick}
  @rows 1_000

  @typedoc "The test context the case's setup builds."
  @type context :: %{required(:repo) => module(), required(:conformance) => map(), optional(atom()) => term()}

  @typedoc "The three subjects of the deny-by-default property."
  @type deny_by_default_subjects :: %{
          known: Mediate.subject(),
          unknown_kind: Mediate.subject(),
          unknown: Mediate.subject()
        }

  @doc "Advance the stubbed clock one second and return the new time."
  @spec tick() :: DateTime.t()
  def tick do
    count = Process.get(@tick_key, 0) + 1
    Process.put(@tick_key, count)
    Clock.set(DateTime.shift(@base, second: count))
  end

  @doc "Replace the tables' world with this one and mirror it into the engine."
  @spec install(context(), World.t()) :: :ok
  def install(%{repo: repo} = context, world) do
    module = World.module(world)
    tick()
    :ok = module.delete(repo)
    :ok = module.write(repo, world)
    mirror(context, world)
  end

  @doc "Mirror the world into the engine's own state, through the case's `mirror:` module when there is one."
  @spec mirror(context(), World.t()) :: :ok
  def mirror(%{conformance: %{mirror: nil}}, _world), do: :ok
  def mirror(%{conformance: %{mirror: mirror}}, world), do: mirror.mirror(world)

  @doc "`ac3-01`: the engine answers `authorized?` as the world's rule does."
  @spec ac3_01(context(), World.t(), Mediate.subject(), atom(), Mediate.resource()) :: true
  def ac3_01(context, world, subject, action, resource) do
    install(context, world)
    module = World.module(world)
    assert Mediate.authorized?(subject, action, resource) == module.allows?(world, subject, action, resource)
  end

  @doc """
  `ac3-02`: the library denies four things:

  - every resource the rule does not grant the subject
  - an unknown action
  - a subject of an unknown kind
  - a subject the world does not know

  It denies the unknown kind before it asks the engine.
  """
  @spec ac3_02(context(), World.t(), deny_by_default_subjects(), atom(), Mediate.resource()) :: :ok
  def ac3_02(context, world, %{known: known, unknown_kind: unknown_kind, unknown: unknown}, action, resource) do
    module = World.module(world)
    install(context, world)
    known_action = hd(module.actions())
    Enum.each(ungranted(module, world, known, known_action), &assert_denied(known, known_action, &1))
    denied_everywhere(known, action, resource)
    denied_everywhere(unknown_kind, known_action, resource)
    denied_or_filtered_to_nothing(context, module, unknown, known_action, resource)

    assert {:error, %Error{reason: :subject_kind_unknown}} = Mediate.authorize(unknown_kind, known_action, resource)
  end

  @doc """
  `ac3-03`: for each protected schema, the rows the filter admits are the
  resources `authorized?` allows. A denied filter admits none.
  """
  @spec ac3_03(context(), World.t(), Mediate.subject(), atom()) :: :ok
  def ac3_03(%{repo: repo} = context, world, subject, action) do
    module = World.module(world)
    install(context, world)
    Enum.each(module.protected_schemas(), &filter_of(repo, module, world, subject, action, &1))
  end

  @doc "`ac3-04`: a filtered `all` over 1,000 rows is one query plus the engine's own, and one decision event."
  @spec ac3_04(context()) :: true
  def ac3_04(%{repo: repo, conformance: %{world: module}} = context) do
    world = module.one_grant_among_many()
    install(context, world)
    :ok = module.fill(repo, world, @rows)
    {subject, _target} = module.grantee(world)

    filtered_all_counted(context, world, subject, hd(module.actions()))
  end

  @doc """
  `ac3-05`: with the engine unreachable, every call denies with
  `:engine_failed` and no policy version. Each call publishes one decision
  event that carries what broke.
  """
  @spec ac3_05(context()) :: :ok
  def ac3_05(%{conformance: %{outage: outage, world: module}} = context) do
    {_world, subject, _target, resource, action} = granted(context, module)

    :ok = outage.disconnect()
    handler = :telemetry_test.attach_event_handlers(self(), [Mediate.event()])
    assert Mediate.authorized?(subject, action, resource) == false
    assert {:error, %Error{reason: :engine_failed}} = Mediate.authorize(subject, action, resource)
    unreachable_filter(subject, action, elem(resource, 0))
    :telemetry.detach(handler)

    events = drain_decisions(handler)
    assert length(events) == 3
    Enum.each(events, &assert_closed/1)
  end

  @doc "`ac2-05`: after a revocation the next `authorized?` denies. The procedure prints the latency and never asserts it."
  @spec ac2_05(context()) :: :ok
  def ac2_05(%{repo: repo, conformance: %{engine: engine, world: module}} = context) do
    {world, subject, target, resource, action} = granted(context, module)

    started = System.monotonic_time(:millisecond)
    revoked = module.revoke(repo, world, subject, target)
    committed = System.monotonic_time(:millisecond)
    mirrored = mirror_component(context, revoked)
    polled = System.monotonic_time(:millisecond)
    assert Test.poll(fn -> not Mediate.authorized?(subject, action, resource) end)
    finished = System.monotonic_time(:millisecond)

    report("""
    revocation latency, #{inspect(engine)}: total #{finished - started} ms
      commit #{committed - started} ms
      mirror #{mirrored}
      poll #{finished - polled} ms, floor #{Test.poll_interval()} ms
      replica_lag not measured
      cache not measured
    """)
  end

  @doc "A single grant written through the mediated repo: one insert, and one identity write event."
  @spec grant_write_budget(context()) :: true
  def grant_write_budget(%{repo: repo, conformance: %{world: module}} = context) do
    world = module.ungranted()
    install(context, world)
    {subject, target} = module.grantee(world)

    {{_granted, writes}, queries} =
      Test.queries(repo, fn -> Test.writes(fn -> module.grant(repo, world, subject, target, []) end) end)

    assert [insert] = queries
    assert insert =~ ~r/^INSERT/i
    assert [%{operation: :create}] = writes
  end

  @doc """
  Print a measurement. The procedures print the measurements and never
  assert them. The test logger sits at warning, so they go to standard
  output as the case promises.
  """
  @spec report(String.t()) :: :ok
  # credo:disable-for-next-line Credo.Check.Refactor.IoPuts
  def report(text) when is_binary(text), do: IO.puts(text)

  @doc """
  What a procedure that takes a grant away starts from. It installs the
  granted world and confirms the grant is in force. It answers the world,
  the grantee, the target, the resource it is over, and an action the
  rule allows.
  """
  @spec granted(context(), module()) :: {World.t(), Mediate.subject(), World.target(), Mediate.resource(), atom()}
  def granted(context, module) do
    world = module.granted()
    install(context, world)
    {subject, target} = module.grantee(world)
    resource = module.resource(target)
    action = hd(module.actions())
    assert Mediate.authorized?(subject, action, resource)
    {world, subject, target, resource, action}
  end

  @doc "`authorized?` and `authorize` deny the subject the action on the resource, with a reason and a message."
  @spec assert_denied(Mediate.subject(), atom(), Mediate.resource()) :: true
  def assert_denied(subject, action, resource) do
    assert Mediate.authorized?(subject, action, resource) == false
    assert {:error, %Error{reason: reason, message: message}} = Mediate.authorize(subject, action, resource)
    assert reason in Error.reasons()
    assert message =~ "may not #{action}"
  end

  @doc """
  The rows the query admits under the decision are exactly the allowed
  ids. A filter decision reads them. A denied decision admits none and
  refuses the read. The table stays readable under the world's exemption.
  """
  @spec assert_admits(module(), module(), Ecto.Queryable.t(), Decision.t(), [term()]) :: true
  def assert_admits(repo, _module, query, %Decision{effect: :filter} = decision, allowed) do
    rows = repo.all(query, authorized_by: decision)
    assert Enum.sort(Enum.map(rows, & &1.id)) == Enum.sort(allowed)
  end

  def assert_admits(repo, module, query, %Decision{effect: :deny} = decision, allowed) do
    assert allowed == []
    assert_raise Error, ~r/may not/, fn -> repo.all(query, authorized_by: decision) end
    assert repo.all(query, authorized_by: module.exemption()) == []
  end

  @doc "The function's result, and the decision events it published, in order."
  @spec decisions((-> result)) :: {result, [map()]} when result: term()
  def decisions(fun) when is_function(fun, 0) do
    handler = :telemetry_test.attach_event_handlers(self(), [Mediate.event()])

    try do
      {fun.(), drain_decisions(handler)}
    after
      :telemetry.detach(handler)
    end
  end

  @doc """
  The decision events this process received on the handler, in order. It
  leaves out the one a call that raised published with no effect.
  """
  @spec drain_decisions(reference()) :: [map()]
  def drain_decisions(handler) do
    receive do
      {[:mediate, :decision], ^handler, _measurements, %{effect: nil}} ->
        drain_decisions(handler)

      {[:mediate, :decision], ^handler, _measurements, metadata} ->
        [metadata | drain_decisions(handler)]
    after
      0 -> []
    end
  end

  defp allowed_ids(module, world, subject, action) do
    type = Schema.resource_type_of(module.budget_schema())

    for {resource_type, id} = resource <- module.resources(world),
        resource_type == type,
        module.allows?(world, subject, action, resource),
        do: id
  end

  defp filter_of(repo, module, world, subject, action, schema) do
    type = Schema.resource_type_of(schema)

    allowed =
      for {resource_type, id} = resource <- module.resources(world),
          resource_type == type,
          Mediate.authorized?(subject, action, resource),
          do: id

    {rule, %Decision{} = decision} = Mediate.filter(subject, action, type)
    assert_admits(repo, module, where(schema, ^rule), decision, allowed)
  end

  defp filtered_all_counted(context, world, subject, action) do
    %{repo: repo, conformance: %{queries_per_call: queries_added, world: module}} = context
    {rows, queries, decisions} = filtered_all(module, repo, subject, action)
    expected = 1 + queries_added

    assert Enum.sort(Enum.map(rows, & &1.id)) == allowed_ids(module, world, subject, action)
    assert length(queries) == expected, "expected #{expected} queries, got #{inspect(queries)}"
    assert decisions == 1
  end

  # The filter of an unreachable engine denies. It names no policy version,
  # because there was none to read.
  defp unreachable_filter(subject, action, type) do
    {_rule, %Decision{} = decision} = Mediate.filter(subject, action, type)
    assert decision.effect == :deny
    assert decision.reason == :engine_failed
    assert decision.policy_version == nil
  end

  defp filtered_all(module, repo, subject, action) do
    schema = module.budget_schema()
    type = Schema.resource_type_of(schema)
    handler = :telemetry_test.attach_event_handlers(self(), [Mediate.event()])

    {rows, queries} =
      Test.queries(repo, fn ->
        {rule, decision} = Mediate.filter(subject, action, type)
        repo.all(where(schema, ^rule), authorized_by: decision)
      end)

    :telemetry.detach(handler)
    {rows, queries, length(drain_decisions(handler))}
  end

  # What brings the engine's own state into step after the revocation, and
  # how long it took. An engine that reads the application's own tables
  # mirrors nothing and has nothing to measure here.
  defp mirror_component(%{conformance: %{mirror: nil}}, _world), do: "not measured"

  defp mirror_component(context, world) do
    started = System.monotonic_time(:millisecond)
    :ok = mirror(context, world)
    "#{System.monotonic_time(:millisecond) - started} ms"
  end

  defp denied_everywhere(subject, action, {type, _id} = resource) do
    assert_denied(subject, action, resource)
    {_rule, %Decision{effect: effect}} = Mediate.filter(subject, action, type)
    assert effect == :deny
  end

  # The library denies a subject the world does not know per resource. Its
  # filter comes back denied or narrows to no row. An engine whose rule is
  # a query learns who the subject is only when the query runs.
  defp denied_or_filtered_to_nothing(%{repo: repo}, module, subject, action, {type, _id} = resource) do
    assert_denied(subject, action, resource)
    schema = Enum.find(module.protected_schemas(), &(Schema.resource_type_of(&1) == type))
    {rule, %Decision{} = decision} = Mediate.filter(subject, action, type)
    assert_admits(repo, module, where(schema, ^rule), decision, [])
  end

  defp ungranted(module, world, subject, action) do
    Enum.reject(module.resources(world), &module.allows?(world, subject, action, &1))
  end

  defp assert_closed(event) do
    assert event.effect == :deny
    assert event.reason == :engine_failed
    assert is_exception(event.exception), "the closed decision carries no exception: #{inspect(event.exception)}"
  end
end
