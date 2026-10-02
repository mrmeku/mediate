defmodule Mediate.Rbac.PolicyTest do
  use ExUnit.Case, async: true

  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Rbac.Conformance.Assignment
  alias Mediate.Rbac.Conformance.Predicates
  alias Mediate.Rbac.Conformance.Reference
  alias Mediate.Rbac.Conformance.Seat
  alias Mediate.Rbac.Domain.Rules
  alias Mediate.Rbac.Policy
  alias Mediate.Rbac.Policy.Resource
  alias Mediate.Rbac.Policy.Role
  alias Mediate.Rbac.Policy.Rule

  defmodule Filters do
    @moduledoc false
    import Ecto.Query, only: [dynamic: 2]

    @spec open() :: Ecto.Query.dynamic_expr()
    def open, do: dynamic([folder], not is_nil(folder.name))
  end

  test "the role table is declared data" do
    assert Policy.roles(Reference) == [
             %Role{name: :reader, actions: [:read]},
             %Role{name: :editor, actions: [:read, :edit]}
           ]

    assert Policy.role_table(Reference) == [reader: [:read], editor: [:read, :edit]]
    assert Policy.actions(Reference) == [:read, :edit]
    assert Policy.roles_for(Reference, :read) == [:reader, :editor]
    assert Policy.roles_for(Reference, :edit) == [:editor]
    assert Policy.roles_for(Reference, :delete) == []
  end

  test "each protected schema carries its rules in declaration order" do
    assert [%Resource{schema: Folder, rules: folder}, %Resource{schema: Item, rules: item}] =
             Policy.resources(Reference)

    assert [
             %Rule{name: :membership, kind: :grant, grant: Membership, on: nil, role_column: :role},
             %Rule{name: :cleared, kind: :predicate, predicate: predicate},
             %Rule{name: :held, kind: :predicate}
           ] = folder

    assert predicate == (&Predicates.cleared/2)

    assert [
             %Rule{name: :folder_membership, kind: :grant, on: :folder_id, role_column: :role},
             %Rule{name: :cleared},
             %Rule{name: :folder_held}
           ] = item

    assert Rules.resource_of(Reference, :item).schema == Item
    assert Rules.resource_of(Reference, :document) == nil
  end

  test "the policy's modules are the policy module and the predicate modules" do
    assert Policy.modules(Reference) == [Predicates, Reference]

    assert Policy.options(Reference) == [
             version: "conformance",
             author: "mediate_rbac",
             approval: "the conformance suite"
           ]
  end

  test "a predicate must be a capture of a named function" do
    assert_raise ArgumentError, ~r/predicate :anonymous is an anonymous function; give a capture/, fn ->
      Rules.predicate(Reference, :anonymous, fn _subject, _context -> true end, [])
    end

    assert %Rule{actions: [:edit]} = Rules.predicate(Reference, :cleared, &Predicates.cleared/2, actions: [:edit])
  end

  test "a hop is a schema and a column, with a named filter when it has one" do
    assert %Rule{through: [{Folder, :id, []}]} =
             Rules.grant(Reference, :hopped, Membership, on: :folder_id, role_column: :role, through: [{Folder, :id}])

    assert %Rule{through: [{Folder, :id, where: filter}]} =
             Rules.grant(Reference, :hopped, Membership,
               on: :folder_id,
               role_column: :role,
               through: [{Folder, :id, where: &Filters.open/0}]
             )

    assert filter == (&Filters.open/0)

    assert_raise NimbleOptions.ValidationError, ~r/has an anonymous where:; give a capture of a named function/, fn ->
      Rules.grant(Reference, :hopped, Membership, role_column: :role, through: [{Folder, :id, where: fn -> true end}])
    end

    assert_raise NimbleOptions.ValidationError,
                 ~r/must be \{schema, column\} or \{schema, column, where: capture\}/,
                 fn ->
                   Rules.grant(Reference, :hopped, Membership, role_column: :role, through: [Folder])
                 end
  end

  test "a grant rule needs the role column named when the grant declares more than one attribute or none" do
    assert %Rule{role: :reader} = Rules.grant(Reference, :fixed, Membership, role: :reader)
    assert %Rule{role_column: :role} = Rules.grant(Reference, :named, Assignment, role_column: :role)
    assert %Rule{role_column: nil, role: nil} = Rules.grant(Reference, :sole, Seat, [])

    assert_raise ArgumentError,
                 ~r/grant rule :wide must name its role column; .*Assignment declares the attributes role, scope/,
                 fn -> Rules.grant(Reference, :wide, Assignment, []) end

    assert_raise ArgumentError, ~r/grant rule :bare reads Mediate.Fixture.Folder, which declares no grant/, fn ->
      Rules.grant(Reference, :bare, Folder, [])
    end

    assert_raise ArgumentError, ~r/resource Mediate.Fixture.Membership declares no resource type/, fn ->
      Rules.resource(Reference, Membership, [])
    end

    assert_raise ArgumentError, ~r/role :reader lists \["read"\]; each action must be an atom/, fn ->
      Policy.__role__(Reference, :reader, ["read"])
    end
  end

  test "every message names the policy module first" do
    assert_raise ArgumentError, ~r/^Mediate.Rbac.Conformance.Reference: /, fn ->
      Rules.grant(Reference, :bare, Folder, [])
    end
  end
end
