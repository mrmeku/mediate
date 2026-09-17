defmodule Example.Domain.Membership do
  @moduledoc "The access path: an account holds a role, maintainer or contributor, in a project."

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Project

  @type t :: %__MODULE__{}

  schema "memberships" do
    field(:user_id, :string)
    field(:role, Ecto.Enum, values: [:maintainer, :contributor])
    belongs_to(:project, Project)
  end

  object_type(:membership)
  audited(:role)
  relationship(subject: :user_id, object: :project_id, attributes: [:role])
end
