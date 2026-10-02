defmodule Mediate.Cerbos.Domain.PlanTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2]

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Domain.Plan
  alias Mediate.Cerbos.Infrastructure.Decide
  alias Mediate.Conformance.Reference.World
  alias Mediate.Dev
  alias Mediate.Dev.Sandbox
  alias Mediate.Error
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Test
  alias Mediate.TestRepos.Sandboxed
  alias Mediate.Verdict

  defmodule Declarations do
    @moduledoc false
    use Mediate.Cerbos.Declarations

    alias Mediate.Cerbos.Conformance.Memberships
    alias Mediate.Fixture.Account

    principal :user, schema: Account do
      attribute :clearance, column: :clearance
    end

    resource :folder, schema: Folder do
      attribute :name, column: :name
      attribute :member_roles, subquery: &Memberships.folder_roles/2
    end

    resource :item, schema: Item do
      attribute :folder, column: :folder_id
    end

    resource :ghost, schema: Folder do
      attribute :missing, column: :nowhere
    end
  end

  setup tags do
    server = Dev.Cerbos.current!()
    :ok = Sandbox.setup(Sandboxed, tags)
    :ok = Test.with_config(engine: {Mediate.Cerbos, address: server.http})

    :ok =
      Binding.override(repo: Sandboxed, declarations: Declarations, policy_dir: server.policy_dir, commit: "conformance")

    world = %World{
      accounts: %{"ann" => World.cleared(), "bob" => nil},
      folders: [1, 2],
      items: %{10 => 1},
      memberships: %{{"ann", 1} => World.held(:reader)}
    }

    :ok = World.write(Sandboxed, world)
    {:ok, binding} = Binding.resolve()

    {:ok,
     binding: binding, address: server.http, ann: {:user, "ann"}, bob: {:user, "bob"}, context: %{now: DateTime.utc_now()}}
  end

  test "a plan that admits every row is every row, and one that admits none is a denial", ctx do
    assert {:ok, rule} = Plan.compile(plan(ctx, :folder, %{"kind" => "KIND_ALWAYS_ALLOWED"}))
    assert ids(rule) == [1, 2]
    assert Plan.compile(plan(ctx, :folder, %{"kind" => "KIND_ALWAYS_DENIED"})) == :denied
  end

  test "a comparison on a declared column is a comparison on the row", ctx do
    assert ids(compiled!(ctx, "eq", [attr("name"), value("folder 1")])) == [1]
    assert ids(compiled!(ctx, "ne", [attr("name"), value("folder 1")])) == [2]
    assert ids(compiled!(ctx, "in", [attr("name"), value(["folder 1", "folder 2"])])) == [1, 2]
  end

  test "an ordering reads the row's id, and the sides swap with the operator", ctx do
    assert ids(compiled!(ctx, "gt", [id_of(), value(1)])) == [2]
    assert ids(compiled!(ctx, "ge", [id_of(), value(2)])) == [2]
    assert ids(compiled!(ctx, "lt", [id_of(), value(2)])) == [1]
    assert ids(compiled!(ctx, "le", [id_of(), value(1)])) == [1]
    assert ids(compiled!(ctx, "lt", [value(1), id_of()])) == [2]
    assert ids(compiled!(ctx, "ge", [value(1), id_of()])) == [1]
    assert ids(compiled!(ctx, "le", [value(2), id_of()])) == [2]
    assert ids(compiled!(ctx, "gt", [value(2), id_of()])) == [1]
    assert ids(compiled!(ctx, "eq", [value("folder 1"), attr("name")])) == [1]
  end

  test "a comparison with nothing is a null test, and an ordering against nothing is no rule", ctx do
    Sandboxed.insert!(%Item{id: 11, title: "item 11"}, authorized_by: World.exemption())

    assert items(ctx, "eq", [attr("folder"), value(nil)]) == [11]
    assert items(ctx, "ne", [attr("folder"), value(nil)]) == [10]

    filter = conditional(expression("gt", [attr("folder"), value(nil)]))

    assert Plan.compile(plan(ctx, :item, filter)) ==
             {:error, "the plan for :read on :item compares gt with nothing, which reads as no rule over the rows"}
  end

  test "a value the subject's subquery selected is membership in the rows it selected", ctx do
    assert ids(compiled!(ctx, "in", [value("reader"), attr("member_roles")])) == [1]
    assert ids(compiled!(ctx, "in", [value("editor"), attr("member_roles")])) == []
  end

  test "and, or, and not join what their operands compile to", ctx do
    one = expression("eq", [attr("name"), value("folder 1")])
    two = expression("eq", [id_of(), value(2)])

    assert ids(compiled!(ctx, "or", [operand(one), operand(two)])) == [1, 2]
    assert ids(compiled!(ctx, "and", [operand(one), operand(two)])) == []
    assert ids(compiled!(ctx, "not", [operand(one)])) == [2]
  end

  test "a plan Mediate.Cerbos does not compile is a refused plan rather than a query", ctx do
    assert {:error, message} = Plan.compile(plan(ctx, :folder, %{"kind" => "KIND_UNSPECIFIED"}))
    assert message =~ "the plan for :read on :folder carries no filter Mediate.Cerbos compiles"

    no_expression = %{"kind" => "KIND_CONDITIONAL", "condition" => %{}}
    assert {:error, message} = Plan.compile(plan(ctx, :folder, no_expression))
    assert message =~ "the plan for :read on :folder carries an operand that is no expression"

    assert {:error, empty} = compiled(ctx, "and", [])
    assert empty == "the plan for :read on :folder uses and with no operands"

    assert {:error, unsupported} = compiled(ctx, "like", [attr("name"), value("folder%")])

    assert unsupported ==
             "the plan for :read on :folder uses the operator like, which Mediate.Cerbos does not compile; " <>
               "keep the condition to eq, ne, lt, le, gt, ge, in, has, and, or, not"

    assert {:error, shape} = compiled(ctx, "size", [attr("name")])
    assert shape =~ "the plan for :read on :folder uses an expression Mediate.Cerbos does not compile"
  end

  test "an operand that carries no rule stops the connective it is under, whichever side it is on", ctx do
    named = expression("eq", [attr("name"), value("folder 1")])
    unreadable = expression("eq", [attr("title"), value("a")])

    assert {:error, second} = compiled(ctx, "and", [operand(named), operand(unreadable)])
    assert second =~ "reads the attribute title, which Mediate.Cerbos.Domain.PlanTest.Declarations does not name"

    assert {:error, right} = compiled(ctx, "eq", [attr("name"), operand(unreadable)])
    assert right =~ "the plan for :read on :folder compares against"
  end

  test "a plan that reads what the declarations do not name is a refused plan", ctx do
    assert {:error, undeclared} = compiled(ctx, "eq", [attr("title"), value("a")])
    assert undeclared =~ "reads the attribute title, which Mediate.Cerbos.Domain.PlanTest.Declarations does not name"

    assert {:error, elsewhere} = compiled(ctx, "eq", [%{"variable" => "request.principal.attr.clearance"}, value("a")])
    assert elsewhere =~ "reads request.principal.attr.clearance, which is no resource attribute"
  end

  test "a plan whose sides Mediate.Cerbos cannot place is a refused plan", ctx do
    assert {:error, both} = compiled(ctx, "eq", [value(1), value(2)])
    assert both == "the plan for :read on :folder compares eq between two sides Mediate.Cerbos cannot place"

    nested = operand(expression("size", [attr("member_roles")]))
    assert {:error, unplaceable} = compiled(ctx, "gt", [nested, value(1)])
    assert unplaceable =~ "the plan for :read on :folder compares against"

    assert {:error, over_subquery} = compiled(ctx, "eq", [attr("member_roles"), value(1)])
    assert over_subquery =~ "uses eq over a subquery attribute and 1"
  end

  test "a value the column cannot hold and a column the schema does not hold are refused plans", ctx do
    assert {:error, cast} = compiled(ctx, "eq", [attr("name"), value(1)])
    assert cast =~ "compares name with 1, which the column cannot hold"

    assert {:error, in_cast} = compiled(ctx, "in", [attr("name"), value([1])])
    assert in_cast =~ "compares name with 1, which the column cannot hold"

    filter = conditional(expression("eq", [%{"variable" => "request.resource.attr.missing"}, value("a")]))
    assert {:error, absent} = Plan.compile(plan(ctx, :ghost, filter))
    assert absent =~ "the plan for :read on :ghost reads nowhere, which Mediate.Fixture.Folder does not hold"
  end

  test "a filter the server denies outright is a denial with the rule that admits no row", ctx do
    assert {:ok, {rule, %Verdict{effect: :deny, reason: :no_rule_matched} = verdict}} =
             Decide.filter(ctx.binding, ctx.address, ctx.bob, :read, :folder, ctx.context)

    assert verdict.policy_version == "conformance"
    assert verdict.meta.plan == :always_denied
    assert is_binary(verdict.meta.request_id)
    assert ids(rule) == []
  end

  test "a plan Mediate.Cerbos cannot compile fails the filter with the sentence that says why", ctx do
    assert {:error, %Error{reason: :engine_failed} = error} =
             Mediate.Cerbos.filter(ctx.ann, :share, :folder, ctx.context, address: ctx.address)

    assert error.message =~ "Mediate.Cerbos failed during filter: the plan for :share on :folder compares against"
  end

  defp compiled!(ctx, operator, operands) do
    {:ok, rule} = compiled(ctx, operator, operands)
    rule
  end

  defp compiled(ctx, operator, operands) do
    Plan.compile(plan(ctx, :folder, conditional(expression(operator, operands))))
  end

  defp plan(ctx, type, filter) do
    {schema, key} = Binding.schema_and_key(ctx.binding, {:resource, type})

    %Plan{
      subject: ctx.ann,
      action: :read,
      context: ctx.context,
      plan: filter,
      declarations: Declarations,
      type: type,
      schema: schema,
      key: key
    }
  end

  defp conditional(expression), do: %{"kind" => "KIND_CONDITIONAL", "condition" => %{"expression" => expression}}
  defp expression(operator, operands), do: %{"operator" => operator, "operands" => operands}
  defp operand(expression), do: %{"expression" => expression}
  defp attr(name), do: %{"variable" => "request.resource.attr." <> name}
  defp id_of, do: %{"variable" => "request.resource.id"}
  defp value(value), do: %{"value" => value}

  defp items(ctx, operator, operands) do
    {:ok, rule} = Plan.compile(plan(ctx, :item, conditional(expression(operator, operands))))
    query = from(i in Item, where: ^rule, select: i.id, order_by: i.id)
    Sandboxed.all(query, authorized_by: World.exemption())
  end

  defp ids(rule) do
    query = from(f in Folder, where: ^rule, select: f.id, order_by: f.id)
    Sandboxed.all(query, authorized_by: World.exemption())
  end
end
