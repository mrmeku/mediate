defmodule Mediate.Cerbos.Infrastructure.ValuesTest do
  use ExUnit.Case, async: true

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Memberships
  alias Mediate.Cerbos.Infrastructure.Values
  alias Mediate.Conformance.Reference.World
  alias Mediate.Dev
  alias Mediate.Dev.Sandbox
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Membership
  alias Mediate.Test
  alias Mediate.TestRepos.Sandboxed

  defmodule Declarations do
    @moduledoc false
    use Mediate.Cerbos.Declarations

    principal :user, schema: Account do
      attribute :clearance, column: :clearance
    end

    principal :privileged, schema: Account do
      attribute :clearance, column: :clearance
    end

    resource :folder, schema: Folder do
      attribute :name, column: :name
      attribute :member_roles, subquery: &Memberships.folder_roles/2
    end

    resource :membership, schema: Membership do
      attribute :role, column: :role
    end

    context do
      fact(:reauthenticated_at)
    end
  end

  setup tags do
    :ok = Sandbox.setup(Sandboxed, tags)
    :ok = Test.with_config(engine: {Mediate.Cerbos, address: Dev.Cerbos.current!().http})

    :ok =
      Binding.override(repo: Sandboxed, declarations: Declarations, policy_dir: "priv/conformance", commit: "conformance")

    world = %World{
      accounts: %{"ann" => World.cleared(), "bob" => nil},
      folders: [1, 2],
      items: %{},
      memberships: %{{"ann", 1} => World.held(:reader)}
    }

    :ok = World.write(Sandboxed, world)
    {:ok, binding} = Binding.resolve()

    {:ok, binding: binding, ann: {:user, "ann"}, bob: {:user, "bob"}, context: %{now: ~U[2026-09-09 12:00:00.123456Z]}}
  end

  test "the subject's own attributes come from the row its id names, the context facts beside them", ctx do
    facts = %{now: "2026-09-09T12:00:00Z", reauthenticated_at: nil}

    assert Values.principal(ctx.binding, ctx.ann, ctx.context) == {:ok, %{clearance: "cleared", context: facts}}
    assert Values.principal(ctx.binding, ctx.bob, ctx.context) == {:ok, %{clearance: nil, context: facts}}
  end

  test "a fact the declarations name travels cut to the second, and one they do not name does not", ctx do
    context = %{
      now: ~U[2026-09-09 12:00:00Z],
      reauthenticated_at: ~U[2026-09-09 11:59:30.987654Z],
      clearance: "cleared"
    }

    assert Values.context(ctx.binding, context) == %{
             now: "2026-09-09T12:00:00Z",
             reauthenticated_at: "2026-09-09T11:59:30Z"
           }
  end

  test "a resource's attributes are its columns and what the subject's subquery selected for it", ctx do
    resources = [{:folder, 1}, {:folder, 2}]

    assert {:ok, by_id} = Values.resources(ctx.binding, ctx.ann, :folder, resources, ctx.context)
    assert by_id["1"] == %{name: "folder 1", member_roles: ["reader"]}
    assert by_id["2"] == %{name: "folder 2", member_roles: []}

    assert {:ok, for_bob} = Values.resources(ctx.binding, ctx.bob, :folder, resources, ctx.context)
    assert for_bob["1"] == %{name: "folder 1", member_roles: []}
  end

  test "a subquery reads the context, so a grant of another kind or past its expiry selects nothing", ctx do
    resources = [{:folder, 1}]
    expired = %{now: ~U[2999-01-02 00:00:00Z]}

    assert {:ok, by_id} = Values.resources(ctx.binding, {:privileged, "ann"}, :folder, resources, ctx.context)
    assert by_id["1"] == %{name: "folder 1", member_roles: []}

    membership = Sandboxed.get_by!(Membership, [account_id: "ann", folder_id: 1], authorized_by: World.exemption())
    changeset = Ecto.Changeset.change(membership, expires_at: ~U[2999-01-01 00:00:00Z])
    _updated = Sandboxed.update!(changeset, authorized_by: World.exemption())

    assert {:ok, live} = Values.resources(ctx.binding, ctx.ann, :folder, resources, ctx.context)
    assert live["1"] == %{name: "folder 1", member_roles: ["reader"]}

    assert {:ok, gone} = Values.resources(ctx.binding, ctx.ann, :folder, resources, expired)
    assert gone["1"] == %{name: "folder 1", member_roles: []}
  end

  test "an id no row holds carries every declared attribute as absent", ctx do
    assert {:ok, by_id} = Values.by_ids(ctx.binding, ctx.ann, {:resource, :folder}, [99], ctx.context)
    assert by_id["99"] == %{name: nil, member_roles: []}
  end

  test "a column the row holds as an atom reaches the server as the text the column holds", ctx do
    [%Membership{id: id}] = Sandboxed.all(Membership, authorized_by: World.exemption())

    assert {:ok, by_id} = Values.by_ids(ctx.binding, ctx.ann, {:resource, :membership}, [id], ctx.context)
    assert by_id[to_string(id)] == %{role: "reader"}
  end

  test "a block no declaration names has no row to read", ctx do
    assert Values.by_ids(ctx.binding, ctx.ann, {:resource, :nothing}, ["x"], ctx.context) ==
             {:error, "Mediate.Cerbos.Infrastructure.ValuesTest.Declarations declares no resource :nothing"}
  end

  test "a value the query cannot cast is left to raise, for the library to turn into a denial", ctx do
    assert_raise Ecto.Query.CastError, fn ->
      Values.by_ids(ctx.binding, ctx.ann, {:resource, :folder}, ["not an identifier"], ctx.context)
    end
  end
end
