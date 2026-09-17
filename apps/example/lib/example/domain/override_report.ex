defmodule Example.Domain.OverrideReport do
  @moduledoc "One audited override, reported to the repository's owning team. No rule reads it."

  use Ecto.Schema

  alias Example.Domain.Repository
  alias Example.Domain.Team

  @type t :: %__MODULE__{}

  schema "override_reports" do
    field(:user_id, :string)
    field(:justification, :string)
    field(:operation_id, :string)
    field(:at, :utc_datetime)
    belongs_to(:repository, Repository)
    belongs_to(:team, Team)
  end
end
