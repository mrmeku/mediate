defmodule Mediate.OpenFGATest.Guard do
  @moduledoc false
  @behaviour Mediate.OpenFGA.Guard

  @impl Mediate.OpenFGA.Guard
  def admits?(:read, context), do: Map.get(context, :cleared) == true
  def admits?(_action, %{now: _now}), do: true
end

defmodule Mediate.OpenFGATest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Config
  alias Mediate.Decision
  alias Mediate.Dev.Sandbox
  alias Mediate.Error
  alias Mediate.OpenFGA
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Client
  alias Mediate.OpenFGA.Client.Fake
  alias Mediate.OpenFGA.Client.ListObjects
  alias Mediate.OpenFGA.Client.Read
  alias Mediate.OpenFGA.Client.Write
  alias Mediate.OpenFGA.Conformance.Population
  alias Mediate.OpenFGA.Conformance.Reference
  alias Mediate.OpenFGA.Drift
  alias Mediate.OpenFGA.Infrastructure.Decide
  alias Mediate.OpenFGA.TupleKey
  alias Mediate.OpenFGATest.Guard
  alias Mediate.Test
  alias Mediate.TestRepos.Sandboxed
  alias Mediate.Verdict

  @now ~U[2026-09-09 12:00:00.000000Z]

  # The engine over a fake, with a store of the test's own, and the markers
  # and the tables in the sandboxed repo the binding names.
  setup tags do
    :ok = Sandbox.setup(Sandboxed, tags)
    agent = start_supervised!(Fake)
    {:ok, store_id} = Fake.create_store(agent, "engine")
    {:ok, model_id} = Fake.write_authorization_model(agent, store_id, %{"schema_version" => "1.1"})

    :ok = Test.with_config(engine: {OpenFGA, address: agent, store_id: store_id, client: Fake, model_id: model_id})

    :ok = Binding.override(repo: Sandboxed, model_file: Reference.model(), mapping: Reference)
    {:ok, options} = options()

    {:ok, agent: agent, store_id: store_id, model_id: model_id, options: options}
  end

  test "the engine states how far one filter reaches, and syncs by passing the outbox" do
    assert OpenFGA.filter_limit() == Decide.limit()
    assert OpenFGA.filter_limit() == 1_000
    assert OpenFGA.sync() == :ok

    schema = OpenFGA.options_schema().schema
    assert schema[:address][:required]
    assert schema[:store_id][:required]
    refute schema[:model_id][:required]
  end

  test "marking every object and syncing fills the store from the tables", context do
    :ok = Population.write(Sandboxed)

    assert OpenFGA.mark_all() == :ok
    assert OpenFGA.sync() == :ok
    assert {:ok, drift} = OpenFGA.reconcile()
    assert Drift.empty?(drift)
    assert %TupleKey{user: "user:acct-a", relation: "editor", object: "folder:1"} = held(context, "folder:1")
  end

  test "a rebuild is a store of its own, carrying the model and every tuple the tables require", context do
    :ok = Population.write(Sandboxed)

    assert {:ok, rebuilt} = OpenFGA.rebuild("rebuilt")
    assert rebuilt != context.store_id
    assert %TupleKey{user: "user:acct-a"} = held(%{context | store_id: rebuilt}, "folder:1")
  end

  test "authorize answers one question under the pinned model", context do
    :ok = write(context, [tuple("ann", "can_read", "folder:1")])
    folder = {:folder, 1}

    assert {:ok, %Verdict{effect: :allow} = allowed} =
             OpenFGA.authorize(ann(), :read, folder, context(), context.options)

    assert allowed.reason == :rule_allowed
    assert allowed.meta.rule == "can_read"
    assert allowed.policy_version == context.model_id

    assert {:ok, %Verdict{effect: :allow}} = OpenFGA.authorize(ann(), :read, folder, context(), context.options)
    assert {:ok, %Verdict{effect: :deny}} = OpenFGA.authorize(ann(), :edit, folder, context(), context.options)
  end

  test "filter answers a rule over the ids of a type", context do
    :ok = write(context, [tuple("ann", "can_read", "folder:1")])

    assert {:ok, {rule, _verdict}} = OpenFGA.filter(ann(), :read, :folder, context(), context.options)
    assert inspect(rule) == inspect(dynamic([row], row.id in ^["1"]))
  end

  test "with nothing bound no callback asks anything", context do
    Process.delete(Binding)
    folder = {:folder, 1}
    text = "nothing bound and no override"

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             OpenFGA.authorize(ann(), :read, folder, context(), context.options)

    assert message == "#{inspect(OpenFGA)} failed during authorize: invalid binding: #{text}"
    assert_failed(OpenFGA.filter(ann(), :read, :folder, context(), context.options), :filter)

    assert {:error, %Error{reason: :invalid, message: invalid}} = OpenFGA.mark_all()
    assert invalid == "invalid binding: #{text}"
  end

  test "a guard the binding names is asked first, and what it refuses the guard denies", context do
    :ok = write(context, [tuple("ann", "can_read", "folder:1")])
    :ok = Binding.override(guard: Guard)
    folder = {:folder, 1}

    assert {:ok, %Verdict{effect: :allow}} = OpenFGA.authorize(ann(), :read, folder, cleared(), context.options)

    assert {:ok, %Verdict{effect: :deny} = denied} =
             OpenFGA.authorize(ann(), :read, folder, context(), context.options)

    assert denied.reason == :rule_denied
    assert denied.meta.rule == Decide.guard_rule()
    assert denied.policy_version == context.model_id

    assert {:ok, {rule, %Verdict{effect: :deny}}} = OpenFGA.filter(ann(), :read, :folder, context(), context.options)

    assert inspect(rule) == inspect(dynamic([_row], false))
  end

  test "what the guard admits still needs a model pinned, and what it refuses does not", context do
    :ok = Binding.override(guard: Guard)
    options = Keyword.delete(context.options, :model_id)
    folder = {:folder, 1}

    assert {:ok, %Verdict{effect: :deny, policy_version: nil}} =
             OpenFGA.authorize(ann(), :read, folder, context(), options)

    assert_failed(OpenFGA.authorize(ann(), :read, folder, cleared(), options), :authorize)
  end

  test "a filter at the limit is a failed engine, and authorize still answers each row", context do
    :ok = readable(context, 1..1_000)

    {rule, %Decision{} = decision} = Mediate.filter(ann(), :read, :folder)

    assert inspect(rule) == inspect(dynamic([_row], false))
    assert decision.effect == :deny
    assert decision.reason == :engine_failed

    kept = for id <- 1..1_000, Mediate.authorized?(ann(), :read, {:folder, id}), do: {:folder, id}

    assert length(kept) == 1_000
    assert Enum.sort(Enum.map(kept, &Decide.object/1)) == Enum.sort(listed(context))
  end

  defp options do
    {:ok, config} = Config.resolve()
    {OpenFGA, options} = Config.engine(config)

    {:ok, options}
  end

  # The one tuple the store holds for an object, for a case that states there
  # is one.
  defp held(context, object) do
    [type, id] = String.split(object, ":", parts: 2)
    request = %Read{object_type: type, object_id: id, page_size: 100}
    {:ok, page} = Fake.read(context.agent, context.store_id, request)

    List.first(page.tuples)
  end

  defp ann, do: {:user, "ann"}

  defp context, do: %{now: @now}

  defp cleared, do: %{now: @now, cleared: true}

  defp tuple(user, relation, object), do: %TupleKey{user: "user:#{user}", relation: relation, object: object}

  defp write(context, tuples) do
    {:ok, _count} = Fake.write(context.agent, context.store_id, %Write{deletes: [], writes: tuples})

    :ok
  end

  # More folders than one `ListObjects` answers with, written in calls of
  # the size one call can carry.
  defp readable(context, ids) do
    ids
    |> Enum.map(&tuple("ann", "can_read", "folder:#{&1}"))
    |> Enum.chunk_every(Client.max_tuples_per_write())
    |> Enum.each(&write(context, &1))
  end

  defp listed(context) do
    request = %ListObjects{user: "user:ann", relation: "can_read", type: "folder"}
    {:ok, objects} = Fake.list_objects(context.agent, context.store_id, request)

    objects
  end

  # A callback that cannot ask the store answers the same error, and names itself in it.
  defp assert_failed(result, callback) do
    assert {:error, %Error{reason: :engine_failed, message: message}} = result
    assert message =~ "during #{callback}"
  end
end
