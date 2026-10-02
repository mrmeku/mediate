defmodule Mediate.Conformance.Procedure.Audit do
  @moduledoc """
  The procedures of the audit requirements, `au2`, `au3`, and `au12`. They
  assert what a decision event, an identity write event, and a resource
  read event carry. They assert what the mediated repo records or refuses
  of a read and a write. Each is a function of the test context, as
  `Mediate.Conformance.Procedure` describes.
  """

  import ExUnit.Assertions

  alias Mediate.Conformance.Procedure
  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.IdentityWrite
  alias Mediate.Schema
  alias Mediate.Test

  @stamped ~w(subject subject_kind action resource effect reason policy_version correlation_id decided_at)a

  @doc """
  `au2-01`: four calls are four decision events. They are an allowed
  `authorize` and `authorized?` for the user, and a denied `authorized?`
  and `authorize` for the privileged subject of the same account. Each
  event carries every field the requirement names.
  """
  @spec au2_01(Procedure.context()) :: true
  def au2_01(%{conformance: %{world: module}} = context) do
    {_world, {kind, account} = subject, _target, resource, action} = Procedure.granted(context, module)
    privileged = {:privileged, account}

    {_results, events} = Procedure.decisions(fn -> four_decisions(subject, privileged, action, resource) end)
    assert_four(events, [subject, subject, privileged, privileged], [kind, kind, :privileged, :privileged])
  end

  @doc "`au2-02`: the event of a denial carries the reason the error names."
  @spec au2_02(Procedure.context()) :: true
  def au2_02(%{conformance: %{world: module}} = context) do
    {_world, {_kind, account}, _target, resource, action} = Procedure.granted(context, module)

    {answer, events} = Procedure.decisions(fn -> Mediate.authorize({:privileged, account}, action, resource) end)

    assert {:error, %Error{reason: reason}} = answer
    assert [%{effect: :deny, reason: ^reason}] = events
    assert reason in Error.reasons()
  end

  @doc "`au2-03`: a filter, and a review of one subject, are three decision events whose effect is `:filter`."
  @spec au2_03(Procedure.context()) :: true
  def au2_03(%{conformance: %{world: module}} = context) do
    {_world, subject, _target, {type, _id}, action} = Procedure.granted(context, module)

    {{filter, review}, events} =
      Procedure.decisions(fn ->
        {Mediate.filter(subject, action, type), Mediate.review(subject, [subject], action, type)}
      end)

    assert {_rule, %Decision{effect: :filter}} = filter
    assert %{^subject => {_rule, %Decision{effect: :filter}}} = review
    assert length(events) == 3
    assert Enum.all?(events, &(&1.effect == :filter))
  end

  @doc """
  `au3-01`: no value the world's rule reads appears in the decision events
  of an allowed `authorize`, a denied `authorized?`, and a filter. The
  filter's event carries the rule where the resource goes. The rule is the
  policy's own text and not a value read from a row, so the comparison
  leaves it out.
  """
  @spec au3_01(Procedure.context()) :: :ok
  def au3_01(%{conformance: %{world: module}} = context) do
    {world, {_kind, account} = subject, _target, resource, action} = Procedure.granted(context, module)
    facts = module.fact_values(world)
    assert facts != [], "#{inspect(module)}.fact_values/1 names no value the rule reads"

    {_results, events} =
      Procedure.decisions(fn -> three_decisions(subject, {:privileged, account}, action, resource) end)

    assert length(events) == 3
    for event <- events, fact <- facts, do: refute_carried(event, fact)
    :ok
  end

  @doc """
  `au3-02`: the event of a grant written carries every fact column from
  nothing to its value. The event of the same grant revoked carries each
  from that value to nothing. Both carry the stamps the requirement
  names.
  """
  @spec au3_02(Procedure.context()) :: true
  def au3_02(%{repo: repo, conformance: %{world: module}} = context) do
    {world, create} = one_grant(context, module)
    assert_identity_write(create, :create)
    assert_from_nothing(create.changes)

    {subject, target} = module.grantee(world)
    {_world, deleted} = Test.writes(fn -> module.revoke(repo, world, subject, target) end)
    assert [delete] = deleted
    assert_identity_write(delete, :delete)
    assert delete.resource == create.resource
    assert delete.changes == reversed(create.changes)
  end

  @doc """
  `au3-03`: a `get` of the granted resource under its decision is one
  resource read event. It carries the resource type, the row's primary
  key, the decision's id, the subject, the correlation id, and the moment.
  """
  @spec au3_03(Procedure.context()) :: true
  def au3_03(%{repo: repo, conformance: %{world: module}} = context) do
    {_world, subject, _target, {type, id} = resource, action} = Procedure.granted(context, module)
    schema = schema_of(module, type)
    {:ok, %Decision{} = decision} = Mediate.authorize(subject, action, resource)

    {read, events} = Test.reads(fn -> repo.get(schema, id, authorized_by: decision) end)
    assert %{__struct__: ^schema} = read
    assert [event] = events
    assert_read(event, decision, type, [id])
  end

  @doc """
  `au3-04`: a decision taken under a given correlation id, a grant written
  under that decision, and a read under it are three events. Each carries
  the correlation id and the decision's id.
  """
  @spec au3_04(Procedure.context()) :: true
  def au3_04(%{conformance: %{world: module}} = context) do
    {world, subject, _target, resource, action} = Procedure.granted(context, module)
    correlation_id = Mediate.Id.new()

    {{:ok, decision}, [decided]} =
      Procedure.decisions(fn -> Mediate.authorize(subject, action, resource, correlation_id: correlation_id) end)

    events = [decided | under_decision(context, world, decision)]
    assert Enum.map(events, & &1.correlation_id) == List.duplicate(correlation_id, 3)
    assert Enum.map(events, & &1.decision_id) == List.duplicate(decision.id, 3)
  end

  @doc "`au12-01`: the mediated repo publishes the identity write event of a grant while the repo is in the write's transaction."
  @spec au12_01(Procedure.context()) :: :ok
  def au12_01(%{repo: repo, conformance: %{world: module}} = context) do
    world = module.ungranted()
    :ok = Procedure.install(context, world)
    {subject, target} = module.grantee(world)
    handler = {__MODULE__, make_ref()}
    config = %{pid: self(), repo: repo}
    :ok = :telemetry.attach(handler, IdentityWrite.event(), &__MODULE__.__in_transaction__/4, config)

    try do
      refute repo.in_transaction?()
      _world = module.grant(repo, world, subject, target, [])
      assert_received {:identity_write_published, in_transaction?}
      assert in_transaction?, "the identity write event was published outside the write's transaction"
    after
      :telemetry.detach(handler)
    end

    :ok
  end

  @doc "`au12-02`: every bulk write to the grant's schema raises, publishes nothing, and leaves the count as it was."
  @spec au12_02(Procedure.context()) :: true
  def au12_02(%{repo: repo, conformance: %{world: module}} = context) do
    {_world, %{schema: schema} = create} = one_grant(context, module)
    exemption = module.exemption()
    [{column, {nil, value}} | _rest] = Map.to_list(create.changes)
    counted = repo.aggregate(schema, :count, authorized_by: exemption)

    calls = [
      {:update_all, [schema, [set: [{column, value}]], [authorized_by: exemption]]},
      {:delete_all, [schema, [authorized_by: exemption]]},
      {:insert_all, [schema, [%{column => value}], [authorized_by: exemption]]}
    ]

    {:ok, events} = Test.writes(fn -> Enum.each(calls, &assert_bulk(repo, &1)) end)
    assert events == []
    assert repo.aggregate(schema, :count, authorized_by: exemption) == counted
  end

  @doc "`au12-03`: a statement written by hand deletes the grant's row and publishes nothing."
  @spec au12_03(Procedure.context()) :: true
  def au12_03(%{repo: repo, conformance: %{world: module}} = context) do
    {_world, %{schema: schema, resource: {_type, id}}} = one_grant(context, module)
    exemption = module.exemption()
    [key] = schema.__schema__(:primary_key)
    statement = "DELETE FROM #{schema.__schema__(:source)} WHERE #{key} = $1"

    {_result, events} = Test.writes(fn -> repo.query!(statement, [id], authorized_by: exemption) end)
    assert events == []
    assert repo.get(schema, id, authorized_by: exemption) == nil
  end

  @doc "`au12-04`: a second grant of the same pair is a write the database refuses, with no row and no event."
  @spec au12_04(Procedure.context()) :: true
  def au12_04(%{repo: repo, conformance: %{world: module}} = context) do
    {world, %{schema: schema}} = one_grant(context, module)
    {subject, target} = module.grantee(world)
    exemption = module.exemption()
    counted = repo.aggregate(schema, :count, authorized_by: exemption)

    {_error, events} =
      Test.writes(fn ->
        assert_raise Ecto.ConstraintError, fn -> module.grant(repo, world, subject, target, []) end
      end)

    assert events == []
    assert repo.aggregate(schema, :count, authorized_by: exemption) == counted
  end

  @doc "`au12-05`: a read and a write of each protected schema with no decision raise `:decision_missing`."
  @spec au12_05(Procedure.context()) :: :ok
  def au12_05(%{repo: repo, conformance: %{world: module}}) do
    Enum.each(module.protected_schemas(), fn schema ->
      read = assert_raise(Error, fn -> repo.all(schema) end)
      assert read.reason == :decision_missing
      write = assert_raise(Error, fn -> repo.insert!(struct(schema)) end)
      assert write.reason == :decision_missing
    end)
  end

  @doc """
  `au12-06`: `get`, `all`, `exists?`, `aggregate`, `stream`, and `reload` of
  the granted resource's schema under its decision each publish one
  resource read event. The event has the cardinality and the primary keys
  the read answers with. The same reads under the world's exemption
  publish none.
  """
  @spec au12_06(Procedure.context()) :: true
  def au12_06(%{repo: repo, conformance: %{world: module}} = context) do
    {_world, subject, _target, {type, id} = resource, action} = Procedure.granted(context, module)
    schema = schema_of(module, type)
    {:ok, %Decision{} = decision} = Mediate.authorize(subject, action, resource)
    reads = reads(repo, schema, repo.get!(schema, id, authorized_by: decision))

    Enum.each(reads, &assert_one_read(&1, decision))
    assert_no_read(reads, module.exemption())
  end

  @doc false
  @spec __in_transaction__([atom()], map(), map(), map()) :: :ok
  def __in_transaction__(_event, _measurements, _payload, %{pid: pid, repo: repo}) do
    if self() == pid, do: send(pid, {:identity_write_published, repo.in_transaction?()})
    :ok
  end

  defp under_decision(%{repo: repo, conformance: %{world: module}}, world, decision) do
    {subject, target} = module.grantee(world)
    {type, id} = module.resource(target)
    revoked = module.revoke(repo, world, subject, target)

    {_world, [written]} =
      Test.writes(fn -> module.grant(repo, revoked, subject, target, authorized_by: decision) end)

    {_read, [read]} = Test.reads(fn -> repo.get(schema_of(module, type), id, authorized_by: decision) end)
    [written, read]
  end

  defp assert_read(event, decision, type, primary_keys) do
    assert event.resource_type == type
    assert event.primary_keys == primary_keys
    assert event.decision_id == decision.id
    assert event.subject == decision.subject
    assert event.correlation_id == decision.correlation_id
    assert %DateTime{} = event.read_at
  end

  defp assert_no_read(reads, exemption) do
    {_results, events} = Test.reads(fn -> Enum.each(reads, fn {read, _cardinality, _keys} -> read.(exemption) end) end)
    assert events == []
  end

  defp assert_one_read({read, cardinality, expected}, decision) do
    {result, events} = Test.reads(fn -> read.(decision) end)
    assert [%{cardinality: ^cardinality, primary_keys: primary_keys, decision_id: decision_id}] = events
    assert primary_keys == expected.(result)
    assert decision_id == decision.id
  end

  # Each read of the schema under a decision or an exemption, with its
  # cardinality. The third element maps what the read answered to the
  # primary keys its resource read event has to name. The stream runs
  # inside a transaction, as Ecto asks. Its one event names no key.
  defp reads(repo, schema, %{__struct__: schema} = row) do
    id = Schema.id_of(row)
    one = fn _result -> [id] end
    none = fn _result -> [] end
    each = fn rows -> Enum.map(rows, &Schema.id_of/1) end

    [
      {fn by -> repo.get(schema, id, authorized_by: by) end, :one, one},
      {fn by -> repo.all(schema, authorized_by: by) end, :many, each},
      {fn by -> repo.exists?(schema, authorized_by: by) end, :one, none},
      {fn by -> repo.aggregate(schema, :count, authorized_by: by) end, :many, none},
      {fn by -> repo.transaction(fn -> repo.stream(schema, authorized_by: by) end) end, :many, none},
      {fn by -> repo.reload(row, authorized_by: by) end, :one, one}
    ]
  end

  defp schema_of(module, type), do: Enum.find(module.protected_schemas(), &(Schema.resource_type_of(&1) == type))

  defp one_grant(%{repo: repo} = context, module) do
    world = module.ungranted()
    :ok = Procedure.install(context, world)
    {subject, target} = module.grantee(world)
    {granted, events} = Test.writes(fn -> module.grant(repo, world, subject, target, []) end)
    assert [create] = events
    {granted, create}
  end

  defp four_decisions(subject, privileged, action, resource) do
    assert {:ok, %Decision{}} = Mediate.authorize(subject, action, resource)
    assert Mediate.authorized?(subject, action, resource)
    refute Mediate.authorized?(privileged, action, resource)
    assert {:error, %Error{}} = Mediate.authorize(privileged, action, resource)
  end

  defp three_decisions(subject, privileged, action, {type, _id} = resource) do
    assert {:ok, %Decision{}} = Mediate.authorize(subject, action, resource)
    refute Mediate.authorized?(privileged, action, resource)
    assert {_rule, %Decision{effect: :filter}} = Mediate.filter(subject, action, type)
  end

  defp refute_carried(event, fact) do
    inspected = inspect(Map.delete(event, :resource))
    refute inspected =~ inspect(fact), "the decision event carries #{inspect(fact)}: #{inspected}"
  end

  defp assert_four(events, subjects, kinds) do
    assert length(events) == 4
    Enum.each(events, &assert_stamped/1)
    assert Enum.map(events, & &1.subject) == subjects
    assert Enum.map(events, & &1.subject_kind) == kinds
    assert Enum.map(events, & &1.effect) == [:allow, :allow, :deny, :deny]
  end

  defp assert_stamped(event) do
    Enum.each(@stamped, fn key ->
      refute is_nil(Map.fetch!(event, key)), "the decision event carries no #{key}: #{inspect(event)}"
    end)
  end

  defp assert_identity_write(event, operation) do
    assert event.operation == operation
    assert is_atom(event.identity_kind)
    assert {type, _id} = event.resource
    assert is_atom(type)
    assert {kind, _id} = event.subject
    assert event.subject_kind == kind
    assert %DateTime{} = event.written_at
    assert is_binary(event.correlation_id)
    assert is_atom(event.schema)
  end

  defp assert_from_nothing(changes) do
    assert map_size(changes) > 0

    Enum.each(changes, fn {column, change} ->
      assert {nil, _value} = change, "#{column} was #{inspect(change)}"
    end)
  end

  defp reversed(changes), do: Map.new(changes, fn {column, {nil, value}} -> {column, {value, nil}} end)

  defp assert_bulk(repo, {name, args}) do
    error = assert_raise(Error, fn -> apply(repo, name, args) end)
    assert Exception.message(error) =~ "bulk write to an identity schema"
  end
end
