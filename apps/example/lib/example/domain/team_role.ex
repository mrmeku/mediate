defmodule Example.Domain.TeamRole do
  @moduledoc """
  An account holds a role, admin or reviewer, in a team. The table admits
  both roles for one account in one team, so the schema declares the row
  twice over. It is the relationship a review reports. It is also an object
  of its own that carries its account, its team, and its role. The second
  declaration tells the two roles apart, because a relationship's key is its
  subject and its object alone.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Team

  @type t :: %__MODULE__{}

  schema "team_roles" do
    field(:user_id, :string)
    field(:role, Ecto.Enum, values: [:admin, :reviewer])
    belongs_to(:team, Team)
  end

  object_type(:team_role)
  audited(:role)
  fact(:user_id, kind: :object_attribute, object: :id)
  fact(:team_id, kind: :object_attribute, object: :id)
  fact(:role, kind: :object_attribute, object: :id)
  relationship(subject: :user_id, object: :team_id, attributes: [:role])
end
