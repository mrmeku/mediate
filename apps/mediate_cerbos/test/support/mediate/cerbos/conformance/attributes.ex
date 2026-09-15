defmodule Mediate.Cerbos.Conformance.Attributes do
  @moduledoc """
  What the conformance policies read. The principal carries the account's
  clearance. A folder and an item each carry the roles the subject holds
  live on the folder.

  Every subject kind has a declaration against the account row. The
  fixture's clearance is the account's, whatever kind asks, and a kind with
  no declaration has no attributes to send. The kind reaches the membership
  subqueries with the subject, and the rule reads it there.
  """

  use Mediate.Cerbos.Attributes

  alias Mediate.Cerbos.Conformance.Memberships
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item

  principal :user, schema: Account do
    attribute :clearance, column: :clearance
  end

  principal :non_person_entity, schema: Account do
    attribute :clearance, column: :clearance
  end

  principal :privileged, schema: Account do
    attribute :clearance, column: :clearance
  end

  resource :folder, schema: Folder do
    attribute :member_roles, subquery: &Memberships.folder_roles_for/2
  end

  resource :item, schema: Item do
    attribute :member_roles, subquery: &Memberships.item_roles_for/2
  end
end
