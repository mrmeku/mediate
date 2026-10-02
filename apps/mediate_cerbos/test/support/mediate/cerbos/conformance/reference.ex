defmodule Mediate.Cerbos.Conformance.Reference do
  @moduledoc """
  The declarations the conformance policy files read. The principal
  carries the account's clearance. A folder and an item each carry the
  roles the subject holds live on the folder.

  Every subject kind has a block against the account row. The world's
  clearance is the account's, whatever kind asks, and a kind with no block
  is `:subject_kind_unknown`. The kind reaches the membership subqueries
  with the subject, and the rule reads it there.
  """

  use Mediate.Cerbos.Declarations

  alias Mediate.Cerbos.Conformance.Memberships
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item

  principal :user, schema: Account do
    attribute :clearance, column: :clearance
  end

  principal :service, schema: Account do
    attribute :clearance, column: :clearance
  end

  principal :privileged, schema: Account do
    attribute :clearance, column: :clearance
  end

  resource :folder, schema: Folder do
    attribute :member_roles, subquery: &Memberships.folder_roles/2
  end

  resource :item, schema: Item do
    attribute :member_roles, subquery: &Memberships.item_roles/2
  end
end
