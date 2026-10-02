defmodule Example.Domain.TeamRole do
  @moduledoc """
  An account holds a role, admin or reviewer, in a team. The table admits
  both roles for one account in one team, so the schema declares the row
  twice over. It is the grant an access review reports. It is also a
  resource of its own that carries its account, its team, and its role. The
  second declaration tells the two roles apart, because a grant's key is
  its subject and its resource alone.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Team

  @type t :: %__MODULE__{}

  schema "team_roles" do
    field(:account_id, :string)
    field(:role, Ecto.Enum, values: [:admin, :reviewer])
    belongs_to(:team, Team)
  end

  resource_type(:team_role)
  identity(:role)
  fact(:account_id, about: :resource, resource: :id)
  fact(:team_id, about: :resource, resource: :id)
  fact(:role, about: :resource, resource: :id)
  grant(subject: :account_id, resource: :team_id, attributes: [:role])
end
