defmodule Example.Domain.Team do
  @moduledoc "A team of an enterprise. A repository's owning team is where admins and reviewers hold roles."

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Enterprise

  @type t :: %__MODULE__{}

  schema "teams" do
    field(:name, :string)
    belongs_to(:enterprise, Enterprise)
  end

  resource_type(:team)
  covers([:enterprise])
  identity(:group)
  fact(:enterprise_id, about: :resource, resource: :id)
end
