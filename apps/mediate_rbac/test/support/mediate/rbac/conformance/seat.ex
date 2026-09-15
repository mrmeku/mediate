defmodule Mediate.Rbac.Conformance.Seat do
  @moduledoc """
  The fixture's membership table as a relationship that declares one
  attribute, the role alone. A grant over such a relationship needs no
  `role:`. This schema is the test case for that default, because the
  fixture's own membership carries the kind and the expiry beside the role.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Fixture.Folder

  @type t :: %__MODULE__{}

  schema "mediate_fixture_memberships" do
    field(:account_id, :string)
    field(:role, Ecto.Enum, values: [:reader, :editor])
    belongs_to(:folder, Folder)
  end

  audited(:role)
  relationship(subject: :account_id, object: :folder_id, attributes: [:role])
end
