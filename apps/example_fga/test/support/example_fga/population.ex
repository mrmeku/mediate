defmodule ExampleFga.Population do
  @moduledoc """
  The world the templates hold `ExampleFga.Infrastructure.TupleMapping` to:

  - the fixture's two tenants and ten accounts
  - a repository with an embargo date, a visibility, an invited account, and
    two directories of its own
  - a second repository with none of those
  - a visibility proposal on the first repository

  `write/1` archives the Globex project at the end. An archived project
  requires no tuple, and a population is worth as much with one as with a
  project that still runs.
  """

  @behaviour Mediate.Fga.Population

  use Boundary, top_level?: true, deps: [Ecto, Example, Example.Fixture, Mediate.Fga]

  alias Example.Domain.AccountRole
  alias Example.Domain.Directory
  alias Example.Domain.Enterprise
  alias Example.Domain.Label
  alias Example.Domain.Membership
  alias Example.Domain.Project
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias Example.Domain.Team
  alias Example.Domain.TeamRole
  alias Example.Domain.User
  alias Example.Domain.Visibility
  alias Example.Fixture
  alias Mediate.Fga.Population

  @exemption {:exempt, "fga population: the world a mapping is held to"}

  # Children before parents, which is the order the foreign keys let rows
  # leave in.
  @tables [
    Proposal,
    Directory,
    Visibility,
    Repository,
    TeamRole,
    Membership,
    AccountRole,
    User,
    Project,
    Team,
    Enterprise,
    Label
  ]

  # An object of each type that no row names. The two attribute types are
  # values rather than rows: a country nobody holds and an employment
  # outside the column's set.
  @absent %{"label" => "NOSUCH", "country" => "ZZ", "employment" => "none"}

  @impl Population
  def write(repo) do
    world = Fixture.world!()

    repository =
      Fixture.repository!(world,
        name: "restricted",
        embargo: DateTime.shift(DateTime.utc_now(:second), day: 365),
        labels: ["secrets"],
        restrictions: [:releasable_to, :invite_only],
        releasable_to: ["US", "FR"],
        invited: ["frank"],
        directories: [
          %{name: "first", contents: "first", labels: ["crypto"], restrictions: [:export_controlled]},
          %{name: "second", contents: "second"}
        ]
      )

    _plain = Fixture.repository!(world, name: "plain", project: world.other_project, team: world.other_team)
    _proposal = insert(repo, %Proposal{repository_id: repository.id, proposer_id: "dana", labels: ["docs"]})
    _archived = Fixture.archive_project!(world.other_project)

    :ok
  end

  @impl Population
  def clear(repo) do
    Enum.each(@tables, fn schema ->
      Enum.each(repo.all(schema, mediate: @exemption), &delete(repo, &1))
    end)
  end

  @impl Population
  def disturb(repo) do
    membership = repo.get_by!(Membership, [user_id: "ann"], mediate: @exemption)

    delete(repo, membership)
  end

  @impl Population
  def absent(type), do: "#{type}:#{Map.get(@absent, type, 999_999)}"

  defp insert(repo, row) do
    _inserted = repo.insert!(row, mediate: @exemption)

    :ok
  end

  defp delete(repo, row) do
    _deleted = repo.delete!(row, mediate: @exemption)

    :ok
  end
end
