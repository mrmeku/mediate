defmodule Mediate.Rbac.Conformance.Tightened do
  @moduledoc """
  The reference world's rule tightened: the same resources, grant rules,
  and predicates as `Mediate.Rbac.Conformance.Reference`, under a role
  table where an editor can edit and no longer read. The change-management
  requirements release it as the version after the boot one, and expect a
  denial of the read the granted editor held.
  """

  use Mediate.Rbac.Policy,
    version: "conformance-tightened",
    author: "mediate_rbac",
    approval: "the conformance suite"

  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Rbac.Conformance.Predicates

  role :reader, [:read]
  role :editor, [:edit]

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
