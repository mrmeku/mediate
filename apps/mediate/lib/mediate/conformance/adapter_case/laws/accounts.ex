defmodule Mediate.Conformance.AdapterCase.Laws.Accounts do
  @moduledoc """
  The bodies of the account laws, `ac2-01` to `ac2-04` and `ac6-01`. They
  assert:

  - what the seam records when a caller writes an account
  - how a grant's expiry and an account's fact reach the next decision
  - what a review answers
  - that a privileged subject holds nothing a user's grant gives

  Each is a function of the test context, as
  `Mediate.Conformance.AdapterCase.Laws` describes.
  """

  import Ecto.Query, only: [where: 2]
  import ExUnit.Assertions

  alias Mediate.Conformance.AdapterCase.Laws
  alias Mediate.Conformance.World
  alias Mediate.Decision
  alias Mediate.Id
  alias Mediate.Schema
  alias Mediate.Test

  @doc """
  `ac2-01`: the write of the granted world creates its account with one
  change event. The clear of the tables deletes it with one. The
  disqualification of the subject updates it with one. Each event names
  the actor the mediation gave, the account as its target, and the fact
  before and after.
  """
  @spec account_changes(Laws.context()) :: true
  def account_changes(%{repo: repo, case: %{world: module}} = context) do
    world = module.granted()
    {{_kind, account} = subject, _grantable} = module.focus(world)

    fact = created(context, world, account)
    deleted(repo, module, account, fact)
    :ok = Laws.populate(context, world)
    updated(repo, world, subject, fact)
  end

  @doc """
  `ac2-02`: a grant that expires one second after the configured clock is
  in force. One that expired one second before is not. The stub holds the
  clock at a moment the database's own clock passed long ago. So an
  adapter that reads the database's clock denies both and fails the law.
  """
  @spec expiry(Laws.context()) :: false
  def expiry(%{repo: repo, case: %{world: module}} = context) do
    world = module.ungranted()
    :ok = Laws.populate(context, world)
    {subject, grantable} = module.focus(world)
    now = Laws.tick()

    live = granted_until(context, world, DateTime.shift(now, second: 1))
    assert allowed?(module, subject, grantable)

    revoked = module.revoke(repo, live, subject, grantable)
    _expired = granted_until(context, revoked, DateTime.shift(now, second: -1))
    refute allowed?(module, subject, grantable)
  end

  @doc "`ac2-03`: the account fact changes with one change event, and the next check denies."
  @spec disqualified(Laws.context()) :: false
  def disqualified(%{repo: repo, case: %{world: module}} = context) do
    {world, subject, _grantable, object, operation} = Laws.granted_focus(context, module)

    {world, events} = Test.changes(fn -> module.disqualify(repo, world, subject) end)
    assert [%{operation: :update}] = events
    :ok = Laws.seed(context, world)
    refute Mediate.check(subject, operation, object)
  end

  @doc """
  `ac2-04`: the last subject of the population reviews every subject it
  knows. The review answers each subject a rule that admits exactly the
  objects `check` allows that subject. It publishes one decision per
  subject and one for the reviewer, all under the operation id of the
  call.
  """
  @spec review(Laws.context(), World.t(), atom()) :: true
  def review(%{repo: repo} = context, world, operation) do
    module = World.module(world)
    :ok = Laws.populate(context, world)
    schema = module.scope_schema()
    subjects = module.subjects(world)
    id = Id.new()

    {reviewed, events} =
      Laws.recorded(fn ->
        Mediate.review(List.last(subjects), subjects, operation, Schema.object_type_of(schema), operation_id: id)
      end)

    assert Enum.sort(Map.keys(reviewed)) == Enum.sort(subjects)
    Enum.each(subjects, &assert_reviewed(repo, world, operation, schema, id, &1, reviewed))
    assert length(Enum.filter(events, &(&1.operation_id == id))) == length(subjects) + 1
  end

  @doc "`ac6-01`: the port allows the user the granted world grants to and denies the privileged subject of the account."
  @spec privileged_denied(Laws.context()) :: true
  def privileged_denied(%{case: %{world: module}} = context) do
    {_world, subject, _grantable, object, operation} = Laws.granted_focus(context, module)
    assert {:user, account} = subject
    Laws.denied({:privileged, account}, operation, object)
  end

  defp created(context, world, account) do
    {:ok, events} = Test.changes(fn -> Laws.populate(context, world) end)
    assert [create] = of(events, account, :create)
    assert_stamped(create)
    assert [{column, {nil, before}}] = Map.to_list(create.changes)
    assert before
    {column, before}
  end

  defp deleted(repo, module, account, {column, before}) do
    {:ok, events} = Test.changes(fn -> module.clear(repo) end)
    assert [delete] = of(events, account, :delete)
    assert_stamped(delete)
    assert delete.changes == %{column => {before, nil}}
  end

  defp updated(repo, world, {_kind, account} = subject, {column, before}) do
    module = World.module(world)
    {_world, events} = Test.changes(fn -> module.disqualify(repo, world, subject) end)
    assert [update] = events
    assert [^update] = of(events, account, :update)
    assert_stamped(update)
    assert [{^column, {^before, changed}}] = Map.to_list(update.changes)
    refute changed == before
  end

  defp of(events, account, operation) do
    Enum.filter(events, &(match?({_type, ^account}, &1.target) and &1.operation == operation))
  end

  defp assert_stamped(event) do
    assert {kind, _id} = event.actor
    assert event.actor_kind == kind
    assert %DateTime{} = event.time
    assert is_binary(event.operation_id)
  end

  defp granted_until(%{repo: repo} = context, world, expires_at) do
    module = World.module(world)
    {subject, grantable} = module.focus(world)
    granted = module.insert_grant(repo, world, subject, grantable, expires_at: expires_at)
    :ok = Laws.seed(context, granted)
    granted
  end

  defp allowed?(module, subject, grantable) do
    Mediate.check(subject, hd(module.operations()), module.object_of(grantable))
  end

  defp assert_reviewed(repo, world, operation, schema, id, subject, reviewed) do
    module = World.module(world)
    type = Schema.object_type_of(schema)
    {rule, %Decision{} = decision} = Map.fetch!(reviewed, subject)
    assert decision.operation_id == id
    assert decision.subject == subject

    allowed =
      for {^type, object_id} = object <- module.objects(world),
          Mediate.check(subject, operation, object),
          do: object_id

    Laws.assert_scope(repo, module, where(schema, ^rule), decision, allowed)
  end
end
