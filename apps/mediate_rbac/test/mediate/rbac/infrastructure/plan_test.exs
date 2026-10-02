defmodule Mediate.Rbac.PlanTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [where: 2]

  alias Mediate.Conformance.Reference.World
  alias Mediate.Dev.Sandbox
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Seat
  alias Mediate.Rbac.Infrastructure.Plan
  alias Mediate.Rbac.Policy
  alias Mediate.TestRepos.Sandboxed
  alias Mediate.Verdict

  defmodule Bools do
    @moduledoc false
    import Ecto.Query, only: [dynamic: 2]

    @spec yes(Mediate.subject(), Mediate.context()) :: boolean()
    def yes(_subject, _context), do: true

    @spec no(Mediate.subject(), Mediate.context()) :: boolean()
    def no(_subject, _context), do: false

    @spec named() :: Ecto.Query.dynamic_expr()
    def named, do: dynamic([folder], folder.name != "closed")
  end

  defmodule FixedRole do
    @moduledoc false
    use Policy, version: "fixed"

    role :reader, [:read]
    role :editor, [:read, :edit]

    resource Folder do
      grant :any_membership, Membership, role: :reader
      predicate :yes, &Bools.yes/2
    end
  end

  defmodule SoleAttribute do
    @moduledoc false
    use Policy, version: "sole"

    role :reader, [:read]
    role :editor, [:read, :edit]

    resource Folder do
      grant :seat, Seat
    end
  end

  defmodule NamedRole do
    @moduledoc false
    use Policy, version: "named"

    role :reader, [:read]
    role :editor, [:read]

    resource Folder do
      grant :membership, Membership, role_column: :role, on: :id
      predicate :no, &Bools.no/2
    end
  end

  defmodule Hopped do
    @moduledoc false
    use Policy, version: "hopped"

    role :reader, [:read]
    role :editor, [:read, :edit]

    resource Item do
      grant :folder_membership, Membership,
        on: :folder_id,
        role_column: :role,
        through: [{Folder, :id, where: &Bools.named/0}]

      predicate :no, &Bools.no/2, actions: [:edit]
    end
  end

  defmodule Unfiltered do
    @moduledoc false
    use Policy, version: "unfiltered"

    role :reader, [:read]
    role :editor, [:read]

    resource Item do
      grant :folder_membership, Membership, on: :folder_id, role_column: :role, through: [{Folder, :id}]
    end
  end

  defmodule Foreign do
    @moduledoc false
    use Policy, version: "foreign"

    role :editor, [:read]
    role :owner, [:read, :edit]

    resource Folder do
      grant :membership, Membership, role_column: :role
    end
  end

  defmodule Composite do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "mediate_plan_test_composite" do
      field(:left, :integer, primary_key: true)
      field(:right, :integer, primary_key: true)
    end
  end

  setup tags do
    :ok = Sandbox.setup(Sandboxed, tags)
    :ok = Mediate.Test.with_config(engine: Mediate.Rbac)

    world = %World{
      accounts: %{"ann" => World.cleared()},
      folders: [1],
      items: %{1 => 1},
      memberships: %{{"ann", 1} => World.held(:editor)}
    }

    :ok = World.write(Sandboxed, world)
    {:ok, context: %{now: DateTime.utc_now()}, ann: {:user, "ann"}}
  end

  test "a grant rule with a fixed role holds through any membership row when the role permits the action", ctx do
    :ok = Binding.override(policy: FixedRole, repo: Sandboxed)
    folder = {:folder, 1}

    assert {:ok, %Verdict{effect: :allow, reason: :rule_allowed, meta: %{rule: "any_membership"}}} =
             Mediate.Rbac.authorize(ctx.ann, :read, folder, ctx.context, [])

    assert {:ok, %Verdict{effect: :deny, reason: :no_rule_matched}} =
             Mediate.Rbac.authorize(ctx.ann, :edit, folder, ctx.context, [])
  end

  test "a role the grant's column cannot hold never matches and raises nothing", ctx do
    :ok = Binding.override(policy: Foreign, repo: Sandboxed)
    folder = {:folder, 1}
    assert {:ok, %Verdict{effect: :allow}} = Mediate.Rbac.authorize(ctx.ann, :read, folder, ctx.context, [])

    assert {:ok, %Verdict{effect: :deny, reason: :no_rule_matched}} =
             Mediate.Rbac.authorize(ctx.ann, :edit, folder, ctx.context, [])
  end

  test "a grant with one attribute needs no role column named, since that attribute is the role", ctx do
    :ok = Binding.override(policy: SoleAttribute, repo: Sandboxed)
    folder = {:folder, 1}

    assert {:ok, %Verdict{effect: :allow, reason: :rule_allowed, meta: %{rule: "seat"}}} =
             Mediate.Rbac.authorize(ctx.ann, :edit, folder, ctx.context, [])
  end

  test "a named role column and a boolean predicate", ctx do
    :ok = Binding.override(policy: NamedRole, repo: Sandboxed)
    folder = {:folder, 1}

    assert {:ok, %Verdict{effect: :deny, reason: :rule_denied, meta: %{rule: "no"}}} =
             Mediate.Rbac.authorize(ctx.ann, :read, folder, ctx.context, [])

    assert {:ok, %Plan{predicates: [no: expression]}} = Plan.build(NamedRole, ctx.ann, :read, :folder, ctx.context)
    assert %Ecto.Query.DynamicExpr{} = expression
  end

  test "a grant rule reaches the row through a hop, the hop filter narrows it, and a predicate applies to its actions",
       ctx do
    :ok = Binding.override(policy: Hopped, repo: Sandboxed)
    item = {:item, 1}

    assert {:ok, %Verdict{effect: :allow, reason: :rule_allowed, meta: %{rule: "folder_membership"}}} =
             Mediate.Rbac.authorize(ctx.ann, :read, item, ctx.context, [])

    assert {:ok, %Verdict{effect: :deny, reason: :rule_denied}} =
             Mediate.Rbac.authorize(ctx.ann, :edit, item, ctx.context, [])

    closed = where(Folder, id: 1)
    {1, nil} = Sandboxed.update_all(closed, [set: [name: "closed"]], authorized_by: World.exemption())

    assert {:ok, %Verdict{effect: :deny, reason: :no_rule_matched}} =
             Mediate.Rbac.authorize(ctx.ann, :read, item, ctx.context, [])

    :ok = Binding.override(policy: Unfiltered, repo: Sandboxed)

    assert {:ok, %Verdict{effect: :allow, reason: :rule_allowed, meta: %{rule: "folder_membership"}}} =
             Mediate.Rbac.authorize(ctx.ann, :read, item, ctx.context, [])
  end

  test "the filter verdict names every rule and the plan needs a one-column primary key", ctx do
    assert {:ok, %Plan{} = plan} = Plan.build(FixedRole, ctx.ann, :read, :folder, ctx.context)
    assert %Verdict{reason: :rule_allowed, meta: %{rule: "any_membership, yes"}} = Plan.verdict(plan)
    rules = Plan.rules(plan)
    assert Enum.sort(Map.keys(rules)) == [:any_membership, :yes]
    assert Plan.primary_key(Folder) == :id
    assert_raise ArgumentError, ~r/has the primary key \[:left, :right\]/, fn -> Plan.primary_key(Composite) end
  end
end
