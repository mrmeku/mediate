defmodule Example.Fixture.Specimen do
  @moduledoc """
  The specimen `Mediate.Conformance.RepoCase` writes when the example holds
  its repo to the five requirements. The identity row is a repository of
  the world's project, whose embargo date is a fact field, under the
  fixture's exemption. An `UPDATE` by hand is the write that goes around
  the mediated repo. The protected row is another such repository, read
  under a decision the fake engine allows.
  """

  @behaviour Mediate.Conformance.Specimen

  import Ecto.Query, only: [from: 2]

  alias Ecto.Changeset
  alias Example.Domain.Project
  alias Example.Domain.Repository
  alias Example.Domain.Team
  alias Example.Fixture
  alias Example.Infrastructure.Repo
  alias Mediate.Conformance.Specimen
  alias Mediate.Dev.Sandbox
  alias Mediate.Test.Fake

  @embargo ~U[2030-01-01 00:00:00Z]
  @by_hand ~U[2031-01-01 00:00:00Z]

  @impl Specimen
  def setup(tags) when is_map(tags) do
    :ok = Sandbox.setup(Repo, tags)
    :ok = Mediate.Test.with_config(engine: {Fake, effect: :allow})
    _world = Fixture.world!()
    :ok
  end

  @impl Specimen
  def identity_row do
    %Repository{name: "conformance", project_id: first!(Project), owning_team_id: first!(Team)}
  end

  @impl Specimen
  def fact_changeset(%Repository{} = repository), do: Changeset.change(repository, embargo: @embargo)

  @impl Specimen
  def authorized_by, do: Fixture.exemption()

  @impl Specimen
  def write_around(%Repository{id: id}) do
    sql = "UPDATE repositories SET embargo = $1 WHERE id = $2"
    _result = Repo.query!(sql, [@by_hand, id], authorized_by: Fixture.exemption())
    :ok
  end

  @impl Specimen
  def protected_row, do: identity_row()

  @impl Specimen
  def read_decision(%Repository{id: id}) do
    {:ok, decision} = Mediate.authorize({:user, "conformance"}, :read, {:repository, id})
    decision
  end

  # The oldest row of a type the world wrote, which is the tenant a
  # conformance repository belongs to.
  defp first!(schema) do
    query = from(row in schema, order_by: [asc: row.id], limit: 1, select: row.id)
    Repo.one!(query, authorized_by: Fixture.exemption())
  end
end
