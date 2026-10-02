defmodule Mediate.OpenFGA.Infrastructure.DecideTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Error
  alias Mediate.OpenFGA.Client.Check
  alias Mediate.OpenFGA.Client.Fake
  alias Mediate.OpenFGA.Client.ListObjects
  alias Mediate.OpenFGA.Client.Write
  alias Mediate.OpenFGA.Infrastructure.Decide
  alias Mediate.OpenFGA.TupleKey
  alias Mediate.Verdict

  @now ~U[2026-09-09 12:00:00.000000Z]

  # A fake on an agent of the test's own answers from its tuples. That is
  # what these cases are about: the request each callback sends and the
  # verdict it makes of the reply. What a model composes is a server's, and
  # the conformance run asks one.
  setup do
    agent = start_supervised!(Fake)
    {:ok, store_id} = Fake.create_store(agent, "decide")
    {:ok, model_id} = Fake.write_authorization_model(agent, store_id, %{"schema_version" => "1.1"})
    options = [client: Fake, address: agent, store_id: store_id, model_id: model_id]
    {:ok, entry} = Decide.entry(options, :authorize, %{now: @now})

    {:ok, agent: agent, store_id: store_id, model_id: model_id, options: options, entry: entry}
  end

  test "an action is a relation, a subject is a user, and a resource is an object of the store" do
    assert Decide.relation(:read) == "can_read"
    assert Decide.relation(:edit) == "can_edit"
    assert Decide.user({:user, "ann"}) == "user:ann"
    assert Decide.user({:service, "importer"}) == "user:importer"
    assert Decide.object({:folder, 1}) == "folder:1"
    assert Decide.time_key() == "current_time"
    assert Decide.kind_key() == "subject_kind"
    assert Decide.limit() == 1_000
  end

  test "the entry is what the configuration names, and an entry naming less is a failed engine", context do
    assert context.entry.client == Fake
    assert context.entry.address == context.agent
    assert context.entry.store_id == context.store_id
    assert context.entry.model_id == context.model_id

    for field <- [:address, :store_id] do
      thin = Keyword.delete(context.options, field)

      assert {:error, %Error{reason: :engine_failed} = error} = Decide.entry(thin, :authorize, %{now: @now})

      assert error.message ==
               "Mediate.OpenFGA failed during authorize: invalid engine: the configuration entry names no #{field}"
    end
  end

  test "an entry without a client named is the client over HTTP", context do
    {:ok, entry} = Decide.entry(Keyword.delete(context.options, :client), :authorize, %{now: @now})

    assert entry.client == Mediate.OpenFGA.Client.HTTP
  end

  test "the context is the caller's facts, the moment under current_time, and the kind under subject_kind", context do
    facts = %{clearance: "cleared", from: ~D[2026-01-01], seen: ~N[2026-01-02 03:04:05], count: 3}
    {:ok, entry} = Decide.entry(context.options, :authorize, Map.put(facts, :now, @now))

    assert {:ok, %Verdict{}} = Decide.one(entry, ann(), :read, {:folder, 1})

    assert [%Check{} = request] = requests(context.agent, :check)

    assert request.context == %{
             "current_time" => "2026-09-09T12:00:00.000000Z",
             "subject_kind" => "user",
             "clearance" => "cleared",
             "from" => "2026-01-01",
             "seen" => "2026-01-02T03:04:05",
             "count" => 3
           }
  end

  test "authorize asks for the higher consistency and filter for the lower one", context do
    assert Decide.consistency(:authorize) == :higher_consistency
    assert Decide.consistency(:filter) == :minimize_latency

    assert {:ok, %Verdict{}} = Decide.one(context.entry, ann(), :read, {:folder, 1})
    assert [%Check{consistency: :higher_consistency, model_id: model_id}] = requests(context.agent, :check)
    assert model_id == context.model_id

    {:ok, filtering} = Decide.entry(context.options, :filter, %{now: @now})
    assert {:ok, {_rule, %Verdict{}}} = Decide.filter(filtering, ann(), :read, :folder)

    assert [%ListObjects{consistency: :minimize_latency, user: "user:ann", relation: "can_read", type: "folder"}] =
             requests(context.agent, :list_objects)
  end

  test "an allowance names the relation that allowed, and a denial is no rule matched", context do
    :ok = write(context, [tuple("ann", "can_read", "folder:1")])

    assert {:ok, %Verdict{} = allowed} = Decide.one(context.entry, ann(), :read, {:folder, 1})
    assert allowed.effect == :allow
    assert allowed.reason == :rule_allowed
    assert allowed.policy_version == context.model_id
    assert allowed.meta == %{rule: "can_read"}

    assert {:ok, %Verdict{} = denied} = Decide.one(context.entry, ann(), :read, {:folder, 2})
    assert denied.effect == :deny
    assert denied.reason == :no_rule_matched
    assert denied.policy_version == context.model_id
    assert denied.meta == %{}
  end

  test "an entry that pins no model asks nothing at all", context do
    {:ok, entry} = Decide.entry(Keyword.delete(context.options, :model_id), :authorize, %{now: @now})
    folder = {:folder, 1}
    text = "the configuration entry pins no model, so no question can be asked under one"

    assert {:error, %Error{reason: :engine_failed, message: asked}} = Decide.one(entry, ann(), :read, folder)
    assert asked == "Mediate.OpenFGA failed during authorize: #{text}"
    assert_pinned(Decide.filter(entry, ann(), :read, :folder), text)

    assert Fake.calls(context.agent) == [
             {:create_store, "decide"},
             {:write_authorization_model, %{"schema_version" => "1.1"}}
           ]
  end

  test "a filter under the limit is the ids of the listing as a rule over rows", context do
    {:ok, entry} = Decide.entry(context.options, :filter, %{now: @now})
    :ok = write(context, [tuple("ann", "can_read", "folder:1"), tuple("ann", "can_read", "folder:2")])

    assert {:ok, {rule, %Verdict{} = verdict}} = Decide.filter(entry, ann(), :read, :folder)
    assert inspect(rule) == inspect(dynamic([row], row.id in ^["1", "2"]))
    assert verdict.effect == :allow
    assert verdict.reason == :rule_allowed
    assert verdict.meta.rule == "can_read"
    assert verdict.policy_version == context.model_id
  end

  test "a filter at the limit is a failed engine that says to authorize each row", context do
    {:ok, entry} = Decide.entry(context.options, :filter, %{now: @now})
    tuples = for id <- 1..Decide.limit(), do: tuple("ann", "can_read", "folder:#{id}")
    Enum.each(Enum.chunk_every(tuples, 100), &write(context, &1))

    assert {:error, %Error{reason: :engine_failed, message: message}} = Decide.filter(entry, ann(), :read, :folder)
    assert message =~ "the server answered 1000 objects"
    assert message =~ "authorize each row instead"
  end

  test "a failed call on the way to the server is the answer, whichever callback asked", context do
    absent = Keyword.put(context.options, :store_id, "store-404")
    {:ok, entry} = Decide.entry(absent, :authorize, %{now: @now})
    folder = {:folder, 1}

    assert {:error, %Error{reason: :engine_failed, message: "Mediate.OpenFGA failed during check" <> _rest}} =
             Decide.one(entry, ann(), :read, folder)

    assert {:error, %Error{reason: :engine_failed, message: "Mediate.OpenFGA failed during list_objects" <> _rest}} =
             Decide.filter(entry, ann(), :read, :folder)
  end

  test "a refusal is the guard's denial under the entry's model, and no row for a filter", context do
    assert %Verdict{effect: :deny, reason: :rule_denied, meta: %{rule: "guard"}} = Decide.refused(context.entry)
    assert Decide.refused(context.entry).policy_version == context.model_id

    assert {rule, %Verdict{effect: :deny}} = Decide.refused_filter(context.entry)
    assert inspect(rule) == inspect(dynamic([_row], false))
  end

  # Both callbacks refuse the same way when the entry pins no model.
  defp assert_pinned(result, text) do
    assert {:error, %Error{reason: :engine_failed, message: said}} = result
    assert said =~ text
  end

  defp ann, do: {:user, "ann"}

  defp tuple(user, relation, object), do: %TupleKey{user: "user:#{user}", relation: relation, object: object}

  defp write(context, tuples) do
    {:ok, _count} = Fake.write(context.agent, context.store_id, %Write{deletes: [], writes: tuples})

    :ok
  end

  defp requests(agent, operation) do
    for {^operation, request} <- Fake.calls(agent), do: request
  end
end
