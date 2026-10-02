defmodule Mediate.Rbac.Conformance.Reference do
  @moduledoc """
  The reference world's rule (`Mediate.Conformance.Reference.World`) as a
  policy module. A reader can read, and an editor can read and edit. A
  folder grants the role its memberships hold. An item grants the role its
  folder's memberships hold. Every allowed subject holds the clearance, and
  the membership the grant rule reads belongs to the subject's kind and
  has not expired. The grant declares three attributes, so each grant rule
  names the role column.
  """

  use Mediate.Rbac.Policy, version: "conformance", author: "mediate_rbac", approval: "the conformance suite"

  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Rbac.Conformance.Predicates

  role :reader, [:read]
  role :editor, [:read, :edit]

  resource Folder do
    grant :membership, Membership, role_column: :role
    predicate :cleared, &Predicates.cleared/2
    predicate :held, &Predicates.held/2
  end

  resource Item do
    grant :folder_membership, Membership, on: :folder_id, role_column: :role
    predicate :cleared, &Predicates.cleared/2
    predicate :folder_held, &Predicates.folder_held/2
  end
end
