defmodule Example.Domain.Membership do
  @moduledoc "The access path: an account holds a role, maintainer or contributor, in a project."

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Project

  @type t :: %__MODULE__{}

  schema "memberships" do
    field(:account_id, :string)
    field(:role, Ecto.Enum, values: [:maintainer, :contributor])
    belongs_to(:project, Project)
  end

  resource_type(:membership)
  identity(:role)
  grant(subject: :account_id, resource: :project_id, attributes: [:role])
end
