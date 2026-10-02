defmodule Mediate.Rbac.Conformance.Seat do
  @moduledoc """
  The reference world's membership table as a grant that declares one
  attribute, the role alone. A grant rule over such a grant needs no
  `role_column:`. This schema is the test case for that default, because
  the world's own membership carries the kind and the expiry beside the
  role.
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

  identity(:role)
  grant(subject: :account_id, resource: :folder_id, attributes: [:role])
end
