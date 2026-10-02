defmodule Example.Domain.OverrideReport do
  @moduledoc "One audited override, reported to the repository's owning team. No clause reads it."

  use Ecto.Schema

  alias Example.Domain.Repository
  alias Example.Domain.Team

  @type t :: %__MODULE__{}

  schema "override_reports" do
    field(:account_id, :string)
    field(:justification, :string)
    field(:correlation_id, :string)
    field(:read_at, :utc_datetime)
    belongs_to(:repository, Repository)
    belongs_to(:team, Team)
  end
end
