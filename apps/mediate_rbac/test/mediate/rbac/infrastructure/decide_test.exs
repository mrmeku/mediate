defmodule Mediate.Rbac.DecideTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Answer
  alias Mediate.Dev.Sandbox
  alias Mediate.Error
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.World
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Roles
  alias Mediate.TestRepos.Sandboxed

  defmodule Broken do
    @moduledoc false
    @spec garbage(Mediate.subject(), Mediate.environment()) :: term()
    def garbage(_subject, _environment), do: :not_a_dynamic
  end

  defmodule BrokenPolicy do
    @moduledoc false
    use Mediate.Rbac.Policy

    role :reader, [:read]

    object Folder do
      predicate :garbage, &Broken.garbage/2
    end
  end

  setup tags do
    :ok = Sandbox.setup(Sandboxed, tags)
    :ok = Mediate.Test.with_config(adapter: Mediate.Rbac)
    :ok = Binding.override(policy: Roles, repo: Sandboxed)

    world =
      Map.put(
        %World{accounts: %{"ann" => World.cleared(), "bob" => nil}, folders: [1, 2], items: %{10 => 1}},
        :memberships,
        %{{"ann", 1} => World.held(:reader), {"bob", 1} => World.held(:editor)}
      )

    :ok = World.insert(Sandboxed, world)
    environment = %{now: DateTime.utc_now()}
    {:ok, environment: environment, ann: {:user, "ann"}, bob: {:user, "bob"}}
  end

  test "the answer names the clauses that held and the reason names the grant or the failing predicate", ctx do
    folder = {:folder, 1}

    allowed = %{rule: "membership", matched: [:membership, :cleared, :held]}

    assert {:ok, %Answer{verdict: :allow, reason: :allowed, meta: ^allowed}} =
             Mediate.Rbac.decide(ctx.ann, :read, folder, ctx.environment, [])

    denied = %{rule: "cleared", matched: [:membership, :held]}

    assert {:ok, %Answer{verdict: :deny, reason: :rule_denied, meta: ^denied}} =
             Mediate.Rbac.decide(ctx.bob, :edit, folder, ctx.environment, [])

    assert {:ok, %Answer{reason: :deny_by_default, meta: %{matched: [:cleared, :held]}}} =
             Mediate.Rbac.decide(ctx.ann, :edit, folder, ctx.environment, [])

    assert {:ok, %Answer{reason: :deny_by_default, meta: %{matched: []}}} =
             Mediate.Rbac.decide(ctx.ann, :read, {:folder, 404}, ctx.environment, [])
  end

  test "an item answers as its folder does, through the grant's on column", ctx do
    item = {:item, 10}
    assert {:ok, %Answer{verdict: :allow}} = Mediate.Rbac.decide(ctx.ann, :read, item, ctx.environment, [])
    assert {:ok, %Answer{verdict: :deny}} = Mediate.Rbac.decide(ctx.ann, :edit, item, ctx.environment, [])
  end

  test "an unknown operation and an unknown object type are denied with their reasons", ctx do
    folder = {:folder, 1}

    assert {:ok, %Answer{verdict: :deny, reason: :unknown_operation}} =
             Mediate.Rbac.decide(ctx.ann, :delete, folder, ctx.environment, [])

    assert {:ok, %Answer{verdict: :deny, reason: :deny_by_default}} =
             Mediate.Rbac.decide(ctx.ann, :read, {:document, 1}, ctx.environment, [])

    assert {:ok, {rule, %Answer{verdict: :deny}}} =
             Mediate.Rbac.scope(ctx.ann, :delete, :folder, ctx.environment, [])

    assert inspect(rule) == inspect(dynamic([_row], false))
  end

  test "one decision is one query", ctx do
    {answer, queries} =
      Mediate.Test.queries(Sandboxed, fn ->
        {:ok, answer} = Mediate.Rbac.decide(ctx.ann, :read, {:folder, 1}, ctx.environment, [])
        answer
      end)

    assert %Answer{verdict: :allow} = answer
    assert length(queries) == 1
  end

  test "a predicate that returns neither a dynamic nor a boolean is an engine error", ctx do
    :ok = Binding.override(policy: BrokenPolicy)

    assert {:error, %Error{reason: :engine_unreachable, detail: detail}} =
             Mediate.Rbac.decide(ctx.ann, :read, {:folder, 1}, ctx.environment, [])

    assert detail =~ "Mediate.Rbac failed during decide"
    assert detail =~ "predicate garbage returned :not_a_dynamic"
  end
end
