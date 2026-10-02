defmodule Mediate.Conformance.Procedure.Accounts do
  @moduledoc """
  The procedures of the account requirements, `ac2-01` to `ac2-04` and
  `ac6-01`. They assert:

  - what the mediated repo records when a caller writes an account
  - how a grant's expiry and an account's fact reach the next decision
  - what a review answers
  - that a privileged subject holds nothing a user's grant gives

  Each is a function of the test context, as
  `Mediate.Conformance.Procedure` describes.
  """

  import Ecto.Query, only: [where: 2]
  import ExUnit.Assertions

  alias Mediate.Conformance.Procedure
  alias Mediate.Conformance.World
  alias Mediate.Decision
  alias Mediate.Id
  alias Mediate.Schema
  alias Mediate.Test

  @doc """
  `ac2-01`: the write of the granted world creates its account with one
  identity write event. The delete of the tables deletes it with one. The
  disqualification of the subject updates it with one. Each event names
  the subject the write carried, the account as its resource, and the
  fact before and after.
  """
  @spec ac2_01(Procedure.context()) :: true
  def ac2_01(%{repo: repo, conformance: %{world: module}} = context) do
    world = module.granted()
    {{_kind, account} = subject, _target} = module.grantee(world)

    fact = created(context, world, account)
    deleted(repo, module, account, fact)
    :ok = Procedure.install(context, world)
    updated(repo, world, subject, fact)
  end

  @doc """
  `ac2-02`: a grant that expires one second after the configured clock is
  in force. One that expired one second before is not. The stub holds the
  clock at a moment the database's own clock passed long ago. So an
  engine that reads the database's clock denies both and fails the
  requirement.
  """
  @spec ac2_02(Procedure.context()) :: false
  def ac2_02(%{repo: repo, conformance: %{world: module}} = context) do
    world = module.ungranted()
    :ok = Procedure.install(context, world)
    {subject, target} = module.grantee(world)
    now = Procedure.tick()

    live = granted_until(context, world, DateTime.shift(now, second: 1))
    assert allowed?(module, subject, target)

    revoked = module.revoke(repo, live, subject, target)
    _expired = granted_until(context, revoked, DateTime.shift(now, second: -1))
    refute allowed?(module, subject, target)
  end

  @doc "`ac2-03`: the account fact changes with one identity write event, and the next `authorized?` denies."
  @spec ac2_03(Procedure.context()) :: false
  def ac2_03(%{repo: repo, conformance: %{world: module}} = context) do
    {world, subject, _target, resource, action} = Procedure.granted(context, module)

    {world, events} = Test.writes(fn -> module.disqualify(repo, world, subject) end)
    assert [%{operation: :update}] = events
    :ok = Procedure.mirror(context, world)
    refute Mediate.authorized?(subject, action, resource)
  end

  @doc """
  `ac2-04`: the last subject of the world reviews every subject it knows.
  The review answers each subject a rule that admits exactly the
  resources `authorized?` allows that subject. It publishes one decision
  per subject and one for the reviewer, all under the correlation id of
  the call.
  """
  @spec ac2_04(Procedure.context(), World.t(), atom()) :: true
  def ac2_04(%{repo: repo} = context, world, action) do
    module = World.module(world)
    :ok = Procedure.install(context, world)
    schema = module.budget_schema()
    subjects = module.subjects(world)
    id = Id.new()

    {reviewed, events} =
      Procedure.decisions(fn ->
        Mediate.review(List.last(subjects), subjects, action, Schema.resource_type_of(schema), correlation_id: id)
      end)

    assert Enum.sort(Map.keys(reviewed)) == Enum.sort(subjects)
    Enum.each(subjects, &assert_reviewed(repo, world, action, schema, id, &1, reviewed))
    assert length(Enum.filter(events, &(&1.correlation_id == id))) == length(subjects) + 1
  end

  @doc "`ac6-01`: the library allows the user the granted world grants to and denies the privileged subject of the account."
  @spec ac6_01(Procedure.context()) :: true
  def ac6_01(%{conformance: %{world: module}} = context) do
    {_world, subject, _target, resource, action} = Procedure.granted(context, module)
    assert {:user, account} = subject
    Procedure.assert_denied({:privileged, account}, action, resource)
  end

  defp created(context, world, account) do
    {:ok, events} = Test.writes(fn -> Procedure.install(context, world) end)
    assert [create] = of(events, account, :create)
    assert_stamped(create)
    assert [{column, {nil, before}}] = Map.to_list(create.changes)
    assert before
    {column, before}
  end

  defp deleted(repo, module, account, {column, before}) do
    {:ok, events} = Test.writes(fn -> module.delete(repo) end)
    assert [delete] = of(events, account, :delete)
    assert_stamped(delete)
    assert delete.changes == %{column => {before, nil}}
  end

  defp updated(repo, world, {_kind, account} = subject, {column, before}) do
    module = World.module(world)
    {_world, events} = Test.writes(fn -> module.disqualify(repo, world, subject) end)
    assert [update] = events
    assert [^update] = of(events, account, :update)
    assert_stamped(update)
    assert [{^column, {^before, changed}}] = Map.to_list(update.changes)
    refute changed == before
  end

  defp of(events, account, operation) do
    Enum.filter(events, &(match?({_type, ^account}, &1.resource) and &1.operation == operation))
  end

  defp assert_stamped(event) do
    assert {kind, _id} = event.subject
    assert event.subject_kind == kind
    assert %DateTime{} = event.written_at
    assert is_binary(event.correlation_id)
  end

  defp granted_until(%{repo: repo} = context, world, expires_at) do
    module = World.module(world)
    {subject, target} = module.grantee(world)
    granted = module.grant(repo, world, subject, target, expires_at: expires_at)
    :ok = Procedure.mirror(context, granted)
    granted
  end

  defp allowed?(module, subject, target) do
    Mediate.authorized?(subject, hd(module.actions()), module.resource(target))
  end

  defp assert_reviewed(repo, world, action, schema, id, subject, reviewed) do
    module = World.module(world)
    type = Schema.resource_type_of(schema)
    {rule, %Decision{} = decision} = Map.fetch!(reviewed, subject)
    assert decision.correlation_id == id
    assert decision.subject == subject

    allowed =
      for {^type, resource_id} = resource <- module.resources(world),
          Mediate.authorized?(subject, action, resource),
          do: resource_id

    Procedure.assert_admits(repo, module, where(schema, ^rule), decision, allowed)
  end
end
