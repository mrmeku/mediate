defmodule Mediate.Rbac.RuleTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [where: 2]

  alias Mediate.Answer
  alias Mediate.Dev.Sandbox
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Fixture.World
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Seat
  alias Mediate.Rbac.Infrastructure.Rule
  alias Mediate.Rbac.Policy
  alias Mediate.TestRepos.Sandboxed

  defmodule Bools do
    @moduledoc false
    import Ecto.Query, only: [dynamic: 2]

    @spec yes(Mediate.subject(), Mediate.environment()) :: boolean()
    def yes(_subject, _environment), do: true

    @spec no(Mediate.subject(), Mediate.environment()) :: boolean()
    def no(_subject, _environment), do: false

    @spec named() :: Ecto.Query.dynamic_expr()
    def named, do: dynamic([folder], folder.name != "closed")
  end

  defmodule FixedRole do
    @moduledoc false
    use Policy, version: "fixed"

    role :reader, [:read]
    role :editor, [:read, :edit]

    object Folder do
      grant :any_membership, Membership, as: :reader
      predicate :yes, &Bools.yes/2
    end
  end

  defmodule SoleAttribute do
    @moduledoc false
    use Policy, version: "sole"

    role :reader, [:read]
    role :editor, [:read, :edit]

    object Folder do
      grant :seat, Seat
    end
  end

  defmodule NamedRole do
    @moduledoc false
    use Policy, version: "named"

    role :reader, [:read]
    role :editor, [:read]

    object Folder do
      grant :membership, Membership, role: :role, on: :id
      predicate :no, &Bools.no/2
    end
  end

  defmodule Hopped do
    @moduledoc false
    use Policy, version: "hopped"

    role :reader, [:read]
    role :editor, [:read, :edit]

    object Item do
      grant :folder_membership, Membership, on: :folder_id, role: :role, through: [{Folder, :id, where: &Bools.named/0}]
      predicate :no, &Bools.no/2, only: [:edit]
    end
  end

  defmodule Unfiltered do
    @moduledoc false
    use Policy, version: "unfiltered"

    role :reader, [:read]
    role :editor, [:read]

    object Item do
      grant :folder_membership, Membership, on: :folder_id, role: :role, through: [{Folder, :id}]
    end
  end

  defmodule Foreign do
    @moduledoc false
    use Policy, version: "foreign"

    role :editor, [:read]
    role :owner, [:read, :edit]

    object Folder do
      grant :membership, Membership, role: :role
    end
  end

  defmodule Composite do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "mediate_rule_test_composite" do
      field(:left, :integer, primary_key: true)
      field(:right, :integer, primary_key: true)
    end
  end

  setup tags do
    :ok = Sandbox.setup(Sandboxed, tags)
    :ok = Mediate.Test.with_config(adapter: Mediate.Rbac)

    world = %World{
      accounts: %{"ann" => World.cleared()},
      folders: [1],
      items: %{1 => 1},
      memberships: %{{"ann", 1} => World.held(:editor)}
    }

    :ok = World.insert(Sandboxed, world)
    {:ok, environment: %{now: DateTime.utc_now()}, ann: {:user, "ann"}}
  end

  test "a grant with a fixed role holds through any membership row when the role permits the operation", ctx do
    :ok = Binding.override(policy: FixedRole, repo: Sandboxed)
    folder = {:folder, 1}

    assert {:ok, %Answer{verdict: :allow, reason: :allowed, meta: %{rule: "any_membership"}}} =
             Mediate.Rbac.decide(ctx.ann, :read, folder, ctx.environment, [])

    assert {:ok, %Answer{verdict: :deny, reason: :deny_by_default}} =
             Mediate.Rbac.decide(ctx.ann, :edit, folder, ctx.environment, [])
  end

  test "a role the relationship's column cannot hold never matches and raises nothing", ctx do
    :ok = Binding.override(policy: Foreign, repo: Sandboxed)
    folder = {:folder, 1}
    assert {:ok, %Answer{verdict: :allow}} = Mediate.Rbac.decide(ctx.ann, :read, folder, ctx.environment, [])

    assert {:ok, %Answer{verdict: :deny, reason: :deny_by_default}} =
             Mediate.Rbac.decide(ctx.ann, :edit, folder, ctx.environment, [])
  end

  test "a relationship with one attribute needs no role column named, since that attribute is the role", ctx do
    :ok = Binding.override(policy: SoleAttribute, repo: Sandboxed)
    folder = {:folder, 1}

    assert {:ok, %Answer{verdict: :allow, reason: :allowed, meta: %{rule: "seat"}}} =
             Mediate.Rbac.decide(ctx.ann, :edit, folder, ctx.environment, [])
  end

  test "a named role column and a boolean predicate", ctx do
    :ok = Binding.override(policy: NamedRole, repo: Sandboxed)
    folder = {:folder, 1}

    assert {:ok, %Answer{verdict: :deny, reason: :rule_denied, meta: %{rule: "no"}}} =
             Mediate.Rbac.decide(ctx.ann, :read, folder, ctx.environment, [])

    assert {:ok, %Rule{predicates: [no: expression]}} = Rule.build(NamedRole, ctx.ann, :read, :folder, ctx.environment)
    assert %Ecto.Query.DynamicExpr{} = expression
  end

  test "a grant reaches the row through a hop, the hop's filter narrows it, and a predicate applies only to its operations",
       ctx do
    :ok = Binding.override(policy: Hopped, repo: Sandboxed)
    item = {:item, 1}

    assert {:ok, %Answer{verdict: :allow, reason: :allowed, meta: %{rule: "folder_membership"}}} =
             Mediate.Rbac.decide(ctx.ann, :read, item, ctx.environment, [])

    assert {:ok, %Answer{verdict: :deny, reason: :rule_denied}} =
             Mediate.Rbac.decide(ctx.ann, :edit, item, ctx.environment, [])

    closed = where(Folder, id: 1)
    {1, nil} = Sandboxed.update_all(closed, [set: [name: "closed"]], mediate: World.exemption())

    assert {:ok, %Answer{verdict: :deny, reason: :deny_by_default}} =
             Mediate.Rbac.decide(ctx.ann, :read, item, ctx.environment, [])

    :ok = Binding.override(policy: Unfiltered, repo: Sandboxed)

    assert {:ok, %Answer{verdict: :allow, reason: :allowed, meta: %{rule: "folder_membership"}}} =
             Mediate.Rbac.decide(ctx.ann, :read, item, ctx.environment, [])
  end

  test "the scope answer names every clause and the rule needs a one-column primary key", ctx do
    assert {:ok, %Rule{} = rule} = Rule.build(FixedRole, ctx.ann, :read, :folder, ctx.environment)
    assert %Answer{reason: :allowed, meta: %{rule: "any_membership, yes"}} = Rule.answer(rule)
    clauses = Rule.clauses(rule)
    assert Enum.sort(Map.keys(clauses)) == [:any_membership, :yes]
    assert Rule.primary_key(Folder) == :id
    assert_raise ArgumentError, ~r/has primary key \[:left, :right\]/, fn -> Rule.primary_key(Composite) end
  end
end
