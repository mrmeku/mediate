defmodule Mediate.Cerbos.FactsTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2, subquery: 1, union_all: 2]

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Reference
  alias Mediate.Cerbos.Facts
  alias Mediate.Cerbos.Infrastructure.Decide
  alias Mediate.Conformance.Reference.World
  alias Mediate.Dev
  alias Mediate.Dev.Sandbox
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Test
  alias Mediate.TestRepos.Sandboxed

  setup tags do
    server = Dev.Cerbos.current!()
    :ok = Sandbox.setup(Sandboxed, tags)
    :ok = Test.with_config(engine: {Mediate.Cerbos, address: server.http})

    :ok =
      Binding.override(repo: Sandboxed, declarations: Reference, policy_dir: server.policy_dir, commit: "conformance")

    world = %World{
      accounts: %{"ann" => World.cleared()},
      folders: [1],
      items: %{10 => 1},
      memberships: %{{"ann", 1} => World.held(:reader)}
    }

    :ok = World.write(Sandboxed, world)
    {:ok, binding} = Binding.resolve()

    {:ok, binding: binding, address: server.http, ann: {:user, "ann"}, context: %{now: DateTime.utc_now()}}
  end

  test "the query the server's own plan compiles to reads declared facts alone", ctx do
    assert {:ok, {folders, _verdict}} = Decide.filter(ctx.binding, ctx.address, ctx.ann, :read, :folder, ctx.context)
    assert Facts.check(ctx.binding, from(f in Folder, where: ^folders)) == :ok

    assert {:ok, {items, _verdict}} = Decide.filter(ctx.binding, ctx.address, ctx.ann, :edit, :item, ctx.context)
    assert Facts.check!(ctx.binding, from(i in Item, where: ^items)) == :ok
  end

  test "a column no declaration covers is a finding naming the schema", ctx do
    query = from(f in Folder, where: f.name == "folder 1")
    assert Facts.check(ctx.binding, query) == {:error, [{Folder, :name}]}

    assert_raise ArgumentError,
                 "the query reads undeclared columns under Mediate.Cerbos.Conformance.Reference: " <>
                   "name of Mediate.Fixture.Folder; declare each as a fact of its schema or drop the read",
                 fn -> Facts.check!(ctx.binding, query) end
  end

  test "a fragment cannot be walked, so it is a finding", ctx do
    query = from(f in Folder, where: fragment("? = 'folder 1'", f.name))

    assert Facts.check(ctx.binding, query) == {:error, [{:fragment, "? = 'folder 1'"}]}
    assert_raise ArgumentError, ~r/fragment "\? = 'folder 1'"/, fn -> Facts.check!(ctx.binding, query) end
  end

  test "the walk follows a subquery, and the grant's own columns are declared", ctx do
    members = from(m in Membership, where: m.account_id == "ann" and m.role == :reader, select: m.folder_id)
    query = from(f in Folder, where: f.id in subquery(members))

    assert Facts.check(ctx.binding, query) == :ok
    reads = Facts.reads(query)
    assert {Membership, :account_id} in reads
    assert {Membership, :role} in reads
    assert {Folder, :id} in reads
  end

  test "the foreign key of a covered relation is declared on the schema that holds it", ctx do
    assert Facts.check(ctx.binding, from(i in Item, where: not is_nil(i.folder_id))) == :ok
  end

  test "a field of a source that is no schema is covered by the walk of that source", ctx do
    members = from(m in Membership, select: %{folder: m.folder_id})

    assert Facts.check(ctx.binding, from(s in subquery(members), where: s.folder > 0)) == :ok
  end

  test "the walk follows the query behind a source, so a column it reads is a finding", ctx do
    named = from(f in Folder, select: %{name: f.name})

    assert Facts.check(ctx.binding, from(s in subquery(named), where: not is_nil(s.name))) ==
             {:error, [{Folder, :name}]}
  end

  test "the walk follows each query a union combines with", ctx do
    ids = from(f in Folder, select: %{id: f.id})
    names = from(f in Folder, select: %{id: f.name})

    assert Facts.check(ctx.binding, union_all(ids, ^names)) == {:error, [{Folder, :name}]}
  end

  test "the walk reads every clause of a query, not the filter alone", ctx do
    query =
      from(f in Folder,
        join: m in Membership,
        on: m.folder_id == f.id,
        where: m.account_id == "ann",
        group_by: f.name,
        having: count(m.id) > 0,
        order_by: f.name,
        select: f.name
      )

    assert Facts.check(ctx.binding, query) == {:error, [{Folder, :name}]}
  end
end
