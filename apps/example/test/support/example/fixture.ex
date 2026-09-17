defmodule Example.Fixture do
  @moduledoc """
  The world every scenario starts from. The fixture inserts it through the
  seam under a declared exemption. It has two enterprises, each with a team
  and a project, and labels with and without implied restrictions. Each
  account holds one role, so a scenario can name the account for the role it
  tests. A scenario adds repositories through `repository!/2`.

  | Account | Kind | Employment | Country | Holds |
  |---|---|---|---|---|
  | ann | user | employee | US | contributor of the Acme project |
  | bob | user | contractor | US | contributor of the Acme project |
  | carl | user | employee | FR | contributor of the Acme project |
  | dana | user | employee | US | admin of the Acme team |
  | eve | user | employee | US | reviewer of the Acme team |
  | frank | user | employee | US | nothing |
  | gil | privileged | employee | US | the override permission, person gil |
  | gil-user | user | employee | US | contributor of the Acme project, person gil |
  | hana | user | employee | US | admin of the Globex team |
  | ivan | user | employee | FR | contributor of the Globex project |
  """

  use Boundary,
    top_level?: true,
    deps: [Example, Ecto, Mediate, Mediate.Conformance, Mediate.Test, Mediate.Dev.Sandbox],
    exports: [Rows]

  import Ecto.Query, only: [from: 2]

  alias Example.Application.Accounts
  alias Example.Domain.Directory
  alias Example.Domain.Enterprise
  alias Example.Domain.Label
  alias Example.Domain.Project
  alias Example.Domain.Repository
  alias Example.Domain.Rollup
  alias Example.Domain.Team
  alias Example.Domain.User
  alias Example.Domain.Visibility
  alias Example.Infrastructure.Repo

  @exempt {:exempt, "fixture: the world a scenario starts from"}

  # Children before parents, which is the order rows leave in.
  @domain ~w(override_reports visibility_proposals directories visibilities repositories team_roles memberships
    account_roles users projects teams enterprises labels)

  @accounts [
    {"ann", :user, :employee, "US", "ann"},
    {"bob", :user, :contractor, "US", "bob"},
    {"carl", :user, :employee, "FR", "carl"},
    {"dana", :user, :employee, "US", "dana"},
    {"eve", :user, :employee, "US", "eve"},
    {"frank", :user, :employee, "US", "frank"},
    {"gil", :privileged, :employee, "US", "gil"},
    {"gil-user", :user, :employee, "US", "gil"},
    {"hana", :user, :employee, "US", "hana"},
    {"ivan", :user, :employee, "FR", "ivan"}
  ]

  @enforce_keys [:enterprise, :team, :project, :other_enterprise, :other_team, :other_project]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          enterprise: Enterprise.t(),
          team: Team.t(),
          project: Project.t(),
          other_enterprise: Enterprise.t(),
          other_team: Team.t(),
          other_project: Project.t()
        }

  @doc "The exemption fixture writes carry."
  @spec exemption() :: {:exempt, String.t()}
  def exemption, do: @exempt

  @doc "The account ids, in the table's order."
  @spec account_ids() :: [String.t()]
  def account_ids, do: Enum.map(@accounts, fn {id, _kind, _employment, _country, _person} -> id end)

  @doc "Insert the world."
  @spec world!() :: t()
  def world! do
    labels!()
    {enterprise, team, project} = tenant!("Acme", "US")
    {other_enterprise, other_team, other_project} = tenant!("Globex", "FR")
    accounts!()
    Accounts.assign("ann", project.id, :contributor)
    Accounts.assign("bob", project.id, :contributor)
    Accounts.assign("carl", project.id, :contributor)
    Accounts.assign("gil-user", project.id, :contributor)
    Accounts.team_role("dana", team.id, :admin)
    Accounts.team_role("eve", team.id, :reviewer)
    Accounts.grant_override("gil")
    Accounts.team_role("hana", other_team.id, :admin)
    Accounts.assign("ivan", other_project.id, :contributor)

    %__MODULE__{
      enterprise: enterprise,
      team: team,
      project: project,
      other_enterprise: other_enterprise,
      other_team: other_team,
      other_project: other_project
    }
  end

  @doc """
  Insert a repository of the world's Acme project with a rollup and
  directories. The rollup is the given visibility combined with the
  directories'. It admits no subject any of them denies. Options:

  - `name:`, `project:`, `team:`, and `embargo:`
  - `labels:`, `restrictions:`, `releasable_to:`, and `invited:`, the visibility
  - `directories:`, a list of maps with `name:`, `contents:` and visibility fields
  """
  @spec repository!(t(), keyword()) :: Repository.t()
  def repository!(%__MODULE__{} = world, opts \\ []) when is_list(opts) do
    project = Keyword.get(opts, :project, world.project)
    team = Keyword.get(opts, :team, world.team)

    %Repository{} =
      repository =
      Repo.insert!(
        %Repository{
          name: Keyword.get(opts, :name, "repository"),
          embargo: opts[:embargo] && DateTime.truncate(opts[:embargo], :second),
          project_id: project.id,
          owning_team_id: team.id
        },
        mediate: @exempt
      )

    directories =
      for attrs <- Keyword.get(opts, :directories, []) do
        Repo.insert!(struct!(%Directory{repository_id: repository.id}, attrs), mediate: @exempt)
      end

    %{repository | visibility: visibility!(repository, opts, directories), directories: directories}
  end

  @doc "Replace the accounts a repository invites, as the fixture, outside any rule."
  @spec set_invited!(Repository.t(), [String.t()]) :: Visibility.t()
  def set_invited!(%Repository{id: id}, accounts) when is_list(accounts) do
    query = from(v in Visibility, where: v.repository_id == ^id)
    visibility = Repo.one!(query, mediate: @exempt)
    Repo.update!(Ecto.Changeset.change(visibility, invited: accounts), mediate: @exempt)
  end

  @doc "Archive a project now, as the fixture."
  @spec archive_project!(Project.t()) :: Project.t()
  def archive_project!(%Project{} = project) do
    now = DateTime.utc_now(:second)
    Repo.update!(Ecto.Changeset.change(project, archived_at: now), mediate: @exempt)
  end

  @doc "The subject for an account of the world."
  @spec subject(String.t()) :: Mediate.subject()
  def subject(id) when is_binary(id) do
    {^id, kind, _employment, _country, _person} = List.keyfind!(@accounts, id, 0)
    {kind, id}
  end

  @doc "Every account's subject."
  @spec subjects() :: [Mediate.subject()]
  def subjects, do: Enum.map(account_ids(), &subject/1)

  @doc "Insert an account with a country and an employment, that holds nothing."
  @spec account!(String.t(), keyword()) :: User.t()
  def account!(id, opts \\ []) when is_binary(id) and is_list(opts) do
    Repo.insert!(
      %User{
        id: id,
        name: id,
        kind: Keyword.get(opts, :kind, :user),
        person_id: id,
        employment: Keyword.get(opts, :employment, :employee),
        country: Keyword.get(opts, :country, "US")
      },
      mediate: @exempt
    )
  end

  @doc """
  Empty every domain table through the owner-role repo, after a committed
  test. A change event is already gone by then, since the library publishes
  one and stores none.
  """
  @spec truncate!(module()) :: :ok
  def truncate!(owner_repo) when is_atom(owner_repo) do
    _result = owner_repo.query!("TRUNCATE #{Enum.join(@domain, ", ")} RESTART IDENTITY CASCADE")
    :ok
  end

  defp labels! do
    rows = [
      %Label{name: "secrets", sensitive: true, implied_restrictions: [:employees_only]},
      %Label{name: "crypto", sensitive: true, implied_restrictions: [:export_controlled]},
      %Label{name: "docs", sensitive: false, implied_restrictions: [:employees_only]}
    ]

    Enum.each(rows, &Repo.insert!(&1, mediate: @exempt))
  end

  defp tenant!(name, country) do
    enterprise = Repo.insert!(%Enterprise{name: name, country: country}, mediate: @exempt)
    team = Repo.insert!(%Team{name: "#{name} team", enterprise_id: enterprise.id}, mediate: @exempt)
    project = Repo.insert!(%Project{name: "#{name} project", team_id: team.id}, mediate: @exempt)
    {enterprise, team, project}
  end

  defp accounts! do
    Enum.each(@accounts, fn {id, kind, employment, country, person} ->
      Repo.insert!(
        %User{id: id, name: id, kind: kind, person_id: person, employment: employment, country: country},
        mediate: @exempt
      )
    end)
  end

  defp visibility!(%Repository{id: id}, opts, directories) do
    rollup = Rollup.of([Map.new(opts) | directories])

    Repo.insert!(
      %Visibility{
        repository_id: id,
        labels: rollup.labels,
        restrictions: rollup.restrictions,
        releasable_to: rollup.releasable_to,
        invited: Keyword.get(opts, :invited, [])
      },
      mediate: @exempt
    )
  end
end
