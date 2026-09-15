defmodule Example.Domain.OfficeRole do
  @moduledoc """
  An account holds a role, designator or approver, in an office. The table
  admits both roles for one account in one office, so the schema declares
  the row twice over. It is the relationship a review reports. It is also an
  object of its own that carries its account, its office, and its role. The
  second declaration tells the two roles apart, because a relationship's key
  is its subject and its object alone.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Office

  @type t :: %__MODULE__{}

  schema "office_roles" do
    field(:user_id, :string)
    field(:role, Ecto.Enum, values: [:designator, :approver])
    belongs_to(:office, Office)
  end

  object_type(:office_role)
  audited(:role)
  fact(:user_id, kind: :object_attribute, object: :id)
  fact(:office_id, kind: :object_attribute, object: :id)
  fact(:role, kind: :object_attribute, object: :id)
  relationship(subject: :user_id, object: :office_id, attributes: [:role])
end
