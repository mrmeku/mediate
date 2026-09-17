defmodule Example.Domain.Project do
  @moduledoc "A project of a team. Membership in it is the access path. When it is archived, every membership's access path ends."

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Team

  @type t :: %__MODULE__{}

  schema "projects" do
    field(:name, :string)
    field(:archived_at, :utc_datetime)
    belongs_to(:team, Team)
  end

  object_type(:project)
  audited(:entity)
  fact(:archived_at, kind: :object_attribute, object: :id)
end
