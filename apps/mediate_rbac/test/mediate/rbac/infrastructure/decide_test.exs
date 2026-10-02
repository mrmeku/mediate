defmodule Mediate.Rbac.DecideTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Conformance.Reference.World
  alias Mediate.Dev.Sandbox
  alias Mediate.Error
  alias Mediate.Fixture.Folder
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Reference
  alias Mediate.TestRepos.Sandboxed
  alias Mediate.Verdict

  defmodule Broken do
    @moduledoc false
    @spec garbage(Mediate.subject(), Mediate.context()) :: term()
    def garbage(_subject, _context), do: :not_a_dynamic
  end

  defmodule BrokenPolicy do
    @moduledoc false
    use Mediate.Rbac.Policy

    role :reader, [:read]

    resource Folder do
      predicate :garbage, &Broken.garbage/2
    end
  end

  setup tags do
    :ok = Sandbox.setup(Sandboxed, tags)
    :ok = Mediate.Test.with_config(engine: Mediate.Rbac)
    :ok = Binding.override(policy: Reference, repo: Sandboxed)

    world =
      Map.put(
        %World{accounts: %{"ann" => World.cleared(), "bob" => nil}, folders: [1, 2], items: %{10 => 1}},
        :memberships,
        %{{"ann", 1} => World.held(:reader), {"bob", 1} => World.held(:editor)}
      )

    :ok = World.write(Sandboxed, world)
    context = %{now: DateTime.utc_now()}
    {:ok, context: context, ann: {:user, "ann"}, bob: {:user, "bob"}}
  end

  test "the verdict names the rules that held and the reason names the grant or the failing predicate", ctx do
    folder = {:folder, 1}

    allowed = %{rule: "membership", matched: ["membership", "cleared", "held"]}

    assert {:ok, %Verdict{effect: :allow, reason: :rule_allowed, meta: ^allowed}} =
             Mediate.Rbac.authorize(ctx.ann, :read, folder, ctx.context, [])

    denied = %{rule: "cleared", matched: ["membership", "held"]}

    assert {:ok, %Verdict{effect: :deny, reason: :rule_denied, meta: ^denied}} =
             Mediate.Rbac.authorize(ctx.bob, :edit, folder, ctx.context, [])

    assert {:ok, %Verdict{reason: :no_rule_matched, meta: %{matched: ["cleared", "held"]}}} =
             Mediate.Rbac.authorize(ctx.ann, :edit, folder, ctx.context, [])

    assert {:ok, %Verdict{reason: :no_rule_matched, meta: %{matched: []}}} =
             Mediate.Rbac.authorize(ctx.ann, :read, {:folder, 404}, ctx.context, [])
  end

  test "an item answers as its folder does, through the grant rule's on column", ctx do
    item = {:item, 10}
    assert {:ok, %Verdict{effect: :allow}} = Mediate.Rbac.authorize(ctx.ann, :read, item, ctx.context, [])
    assert {:ok, %Verdict{effect: :deny}} = Mediate.Rbac.authorize(ctx.ann, :edit, item, ctx.context, [])
  end

  test "an unknown action and an unknown resource type are denied with their reasons", ctx do
    folder = {:folder, 1}

    assert {:ok, %Verdict{effect: :deny, reason: :action_unknown}} =
             Mediate.Rbac.authorize(ctx.ann, :delete, folder, ctx.context, [])

    assert {:ok, %Verdict{effect: :deny, reason: :no_rule_matched}} =
             Mediate.Rbac.authorize(ctx.ann, :read, {:document, 1}, ctx.context, [])

    assert {:ok, {expression, %Verdict{effect: :deny}}} =
             Mediate.Rbac.filter(ctx.ann, :delete, :folder, ctx.context, [])

    assert inspect(expression) == inspect(dynamic([_row], false))
  end

  test "one verdict is one query", ctx do
    {verdict, queries} =
      Mediate.Test.queries(Sandboxed, fn ->
        {:ok, verdict} = Mediate.Rbac.authorize(ctx.ann, :read, {:folder, 1}, ctx.context, [])
        verdict
      end)

    assert %Verdict{effect: :allow} = verdict
    assert length(queries) == 1
  end

  test "a predicate that returns neither a dynamic nor a boolean is an engine failure", ctx do
    :ok = Binding.override(policy: BrokenPolicy)

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             Mediate.Rbac.authorize(ctx.ann, :read, {:folder, 1}, ctx.context, [])

    assert message ==
             "Mediate.Rbac failed during authorize: predicate garbage returned :not_a_dynamic, not a dynamic or a boolean"
  end
end
