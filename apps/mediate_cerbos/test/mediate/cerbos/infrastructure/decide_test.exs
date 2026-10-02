defmodule Mediate.Cerbos.Infrastructure.DecideTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2]

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Reference
  alias Mediate.Cerbos.Infrastructure.Decide
  alias Mediate.Conformance.Reference.World
  alias Mediate.Dev
  alias Mediate.Dev.Sandbox
  alias Mediate.Test
  alias Mediate.TestRepos.Sandboxed
  alias Mediate.Verdict

  setup tags do
    server = Dev.Cerbos.current!()
    :ok = Sandbox.setup(Sandboxed, tags)
    :ok = Test.with_config(engine: {Mediate.Cerbos, address: server.http})

    :ok =
      Binding.override(repo: Sandboxed, declarations: Reference, policy_dir: server.policy_dir, commit: "conformance")

    world = %World{
      accounts: %{"ann" => World.cleared(), "bob" => nil},
      folders: [1, 2],
      items: %{10 => 1},
      memberships: %{{"ann", 1} => World.held(:editor)}
    }

    :ok = World.write(Sandboxed, world)
    {:ok, binding} = Binding.resolve()

    {:ok,
     binding: binding, address: server.http, ann: {:user, "ann"}, bob: {:user, "bob"}, context: %{now: DateTime.utc_now()}}
  end

  test "an allow names the policy the server evaluated and the request id", ctx do
    assert {:ok, %Verdict{effect: :allow, reason: :rule_allowed} = verdict} =
             Decide.one(ctx.binding, ctx.address, ctx.ann, :edit, {:folder, 1}, ctx.context)

    assert verdict.policy_version == "conformance"
    assert verdict.meta.policy =~ "folder"
    assert is_binary(verdict.meta.request_id)
  end

  test "a denial is no rule matched, naming the policy the server evaluated", ctx do
    assert {:ok, %Verdict{effect: :deny, reason: :no_rule_matched} = verdict} =
             Decide.one(ctx.binding, ctx.address, ctx.ann, :edit, {:folder, 2}, ctx.context)

    assert verdict.meta.policy =~ "folder"

    assert {:ok, %Verdict{effect: :deny, reason: :no_rule_matched}} =
             Decide.one(ctx.binding, ctx.address, ctx.bob, :read, {:item, 10}, ctx.context)
  end

  test "a subject kind no block declares is unknown, and a resource type no block declares matches no rule", ctx do
    assert {:ok, %Verdict{effect: :deny, reason: :subject_kind_unknown, meta: %{subject_kind: :robot}}} =
             Decide.one(ctx.binding, ctx.address, {:robot, "ann"}, :read, {:folder, 1}, ctx.context)

    assert {:ok, %Verdict{effect: :deny, reason: :no_rule_matched, meta: %{resource_type: :nothing}}} =
             Decide.one(ctx.binding, ctx.address, ctx.ann, :read, {:nothing, 1}, ctx.context)

    assert {:ok, {_rule, %Verdict{effect: :deny, reason: :subject_kind_unknown}}} =
             Decide.filter(ctx.binding, ctx.address, {:robot, "ann"}, :read, :folder, ctx.context)

    assert {:ok, {_rule, %Verdict{effect: :deny, reason: :no_rule_matched, meta: %{resource_type: :nothing}}}} =
             Decide.filter(ctx.binding, ctx.address, ctx.ann, :read, :nothing, ctx.context)
  end

  test "a conditional plan is an allow whose rule admits the granted rows alone", ctx do
    assert {:ok, {rule, %Verdict{effect: :allow, reason: :rule_allowed, meta: %{plan: :conditional}}}} =
             Decide.filter(ctx.binding, ctx.address, ctx.ann, :read, :folder, ctx.context)

    query = from(f in Mediate.Fixture.Folder, where: ^rule, select: f.id)
    assert Sandboxed.all(query, authorized_by: World.exemption()) == [1]
  end

  test "a server out of reach is a failure naming the server", ctx do
    assert {:error, message} = Decide.one(ctx.binding, "127.0.0.1:1", ctx.ann, :read, {:folder, 1}, ctx.context)
    assert message =~ "the Cerbos server at 127.0.0.1:1 could not be reached"
  end
end
