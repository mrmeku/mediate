defmodule ExampleOpenFGA.Infrastructure.Mapping do
  @moduledoc """
  The example's tables as tuples of the model under `priv/policies`.

  This is the half of the mapping that reads rows. It answers the four
  questions `Mediate.OpenFGA.Mapping` asks, each from the tables through
  the repo it gets. What a row then requires is the other half, a hidden
  module beside this one, which reads nothing.

  A subject attribute is membership of its value as an object of its own,
  because a graph compares by a walk and not by equality. So an account's
  country is `member` of a country, and its employment is `member` of
  an employment.

  A directory's tuples take the repository's embargo date, because the
  column that holds the date is the repository's. So this half fetches the
  repository row and gives the other half the date.

  A change can name more objects than the row it ran on. A date that
  lifts a repository's embargo changes what every directory of it
  requires. A row that moved between two parents names both: the parent it
  left, from the change, and the parent it joined, from the row.

  The table below says what each object's rows require. An object whose
  rows are gone requires nothing.

  ## What each object's rows require

  | Object | Tuples (user, relation, object) |
  |---|---|
  | `enterprise:A` | `country:CC home enterprise:A` for the enterprise's country, and `employment:employee employee enterprise:A` |
  | `team:O` | `enterprise:A enterprise team:O`, and `user:U admin team:O` or `user:U reviewer team:O`, one tuple per team-role row |
  | `project:P` | `user:U contributor project:P` or `user:U maintainer project:P` per membership in an open project, and an archived project requires none of them |
  | `label:C` | `user:* employee_applies label:C` and `user:* export_applies label:C` for the restrictions the label implies |
  | `country:CC`, `employment:E` | `user:U member country:CC` and `user:U member employment:E`, from each account's country and employment |
  | `repository:D` | `project:P project repository:D` and `team:O owning_team repository:D`. `label:C label repository:D` and `user:* <restriction>_applies repository:D` from the visibility, each with `under_embargo` where the repository has an embargo date. `country:CC releasable_to repository:D`, and `user:U invited repository:D` per account the visibility invites |
  | `directory:X` | `repository:D repository directory:X` and `directory:X directory repository:D`, and the directory's own labels, restrictions, and countries, with the repository's embargo date |
  | `proposal:R` | `team:O team proposal:R` and `user:U proposer proposal:R` |
  """

  @behaviour Mediate.OpenFGA.Mapping

  import Ecto.Query, only: [from: 2]

  alias Example.Domain.Account
  alias Example.Domain.Directory
  alias Example.Domain.Enterprise
  alias Example.Domain.Label
  alias Example.Domain.Membership
  alias Example.Domain.Project
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias Example.Domain.Team
  alias Example.Domain.TeamRole
  alias Example.Domain.Visibility
  alias ExampleOpenFGA.Infrastructure.Tuples
  alias Mediate.OpenFGA.Mapping

  # The types that carry tuples. An account is `user`, and the model gives
  # `user` no relation of its own, so no tuple has an account as its object.
  @object_types ~w[enterprise team project label country employment repository directory proposal]

  # An enterprise's own staff are the accounts whose employment is employee,
  # which is what EMPLOYEE ONLY clears.
  @employee_object "employment:employee"

  @exemption {:exempt, "mapping: the rows an object's tuples are read from"}

  @impl Mapping
  def object_types, do: @object_types

  @impl Mapping
  def objects(repo, type), do: Tuples.object(type, ids(repo, type))

  @impl Mapping
  def affected(_repo, %{schema: Account, changes: changes}) do
    Tuples.object("country", moved(changes, :country)) ++ Tuples.object("employment", moved(changes, :employment))
  end

  def affected(_repo, %{schema: Enterprise, resource: {_type, id}}), do: ["enterprise:#{id}"]

  def affected(_repo, %{schema: Team, resource: {_type, id}}), do: ["team:#{id}"]

  def affected(repo, %{schema: TeamRole, resource: {_type, id}, changes: changes}) do
    Tuples.object("team", moved(changes, :team_id) ++ held(repo, TeamRole, id, :team_id))
  end

  def affected(_repo, %{schema: Project, resource: {_type, id}}), do: ["project:#{id}"]

  def affected(repo, %{schema: Membership, resource: {_type, id}, changes: changes}) do
    Tuples.object("project", moved(changes, :project_id) ++ held(repo, Membership, id, :project_id))
  end

  def affected(_repo, %{schema: Label, resource: {_type, name}}), do: ["label:#{name}"]

  def affected(repo, %{schema: Repository, resource: {_type, id}}) do
    [
      "repository:#{id}"
      | from_repository(repo, Directory, "directory", id) ++ from_repository(repo, Proposal, "proposal", id)
    ]
  end

  def affected(repo, %{schema: Visibility, resource: {_type, id}}) do
    Tuples.object("repository", held(repo, Visibility, id, :repository_id))
  end

  def affected(repo, %{schema: Directory, resource: {_type, id}, changes: changes}) do
    repositories = moved(changes, :repository_id) ++ held(repo, Directory, id, :repository_id)

    ["directory:#{id}" | Tuples.object("repository", repositories)]
  end

  def affected(_repo, %{schema: Proposal, resource: {_type, id}}), do: ["proposal:#{id}"]

  def affected(_repo, %{}), do: []

  @impl Mapping
  def tuples(repo, object) do
    case String.split(object, ":", parts: 2) do
      [type, id] -> required(repo, type, id)
      _untyped -> []
    end
  end

  defp ids(repo, "enterprise"), do: rows(repo, from(enterprise in Enterprise, select: enterprise.id))
  defp ids(repo, "team"), do: rows(repo, from(team in Team, select: team.id))
  defp ids(repo, "project"), do: rows(repo, from(project in Project, select: project.id))
  defp ids(repo, "label"), do: rows(repo, from(label in Label, select: label.name))
  defp ids(repo, "country"), do: held_by_accounts(repo, :country)
  defp ids(repo, "employment"), do: held_by_accounts(repo, :employment)
  defp ids(repo, "repository"), do: rows(repo, from(repository in Repository, select: repository.id))
  defp ids(repo, "directory"), do: rows(repo, from(directory in Directory, select: directory.id))
  defp ids(repo, "proposal"), do: rows(repo, from(proposal in Proposal, select: proposal.id))
  defp ids(_repo, _type), do: []

  # The values accounts hold in a subject attribute, each an object of its
  # own. A value no account holds is an object nothing walks to. So a country
  # a visibility releases to, and no account belongs to, is not one of these.
  defp held_by_accounts(repo, :country) do
    rows(repo, from(account in Account, where: not is_nil(account.country), distinct: true, select: account.country))
  end

  defp held_by_accounts(repo, :employment) do
    rows(
      repo,
      from(account in Account, where: not is_nil(account.employment), distinct: true, select: account.employment)
    )
  end

  defp required(repo, "enterprise", id), do: enterprise_tuples(repo, id)
  defp required(repo, "team", id), do: team_tuples(repo, id)
  defp required(repo, "project", id), do: project_tuples(repo, id)
  defp required(repo, "label", name), do: label_tuples(repo, name)
  defp required(repo, "country", value), do: country_tuples(repo, value)
  defp required(repo, "employment", value), do: employment_tuples(repo, value)
  defp required(repo, "repository", id), do: repository_tuples(repo, id)
  defp required(repo, "directory", id), do: directory_tuples(repo, id)
  defp required(repo, "proposal", id), do: proposal_tuples(repo, id)
  defp required(_repo, _type, _id), do: []

  # The enterprise's country and the employment its own staff hold. The
  # override permission lives outside any enterprise and outside the model, so
  # an enterprise requires nothing of the accounts that hold it.
  defp enterprise_tuples(repo, id) do
    case row(repo, Enterprise, id) do
      %Enterprise{country: country} when is_binary(country) ->
        [
          Tuples.key("country:#{country}", "home", "enterprise:#{id}"),
          Tuples.key(@employee_object, "employee", "enterprise:#{id}")
        ]

      _absent ->
        []
    end
  end

  defp team_tuples(repo, id) do
    case row(repo, Team, id) do
      %Team{enterprise_id: nil} -> role_tuples(repo, id)
      %Team{enterprise_id: enterprise} -> [enterprise_link(enterprise, id) | role_tuples(repo, id)]
      nil -> []
    end
  end

  defp enterprise_link(enterprise, id), do: Tuples.key("enterprise:#{enterprise}", "enterprise", "team:#{id}")

  defp role_tuples(repo, id) do
    query =
      from(role in TeamRole,
        where: role.team_id == ^id and not is_nil(role.role),
        distinct: true,
        select: {role.account_id, role.role}
      )

    Tuples.roles(rows(repo, query), "team:#{id}")
  end

  # An archived project is an access path that has ended. So it requires no
  # tuple, and no membership to it requires one.
  defp project_tuples(repo, id) do
    case row(repo, Project, id) do
      %Project{archived_at: nil} -> membership_tuples(repo, id)
      _archived_or_absent -> []
    end
  end

  defp membership_tuples(repo, id) do
    query =
      from(membership in Membership,
        where: membership.project_id == ^id and not is_nil(membership.role),
        distinct: true,
        select: {membership.account_id, membership.role}
      )

    Tuples.roles(rows(repo, query), "project:#{id}")
  end

  # A label that is not sensitive implies nothing, whatever its
  # restrictions column holds, which is what the sensitive column decides.
  defp label_tuples(repo, name) do
    case row(repo, Label, name) do
      %Label{sensitive: true, implied_restrictions: restrictions} -> Tuples.implied(restrictions, "label:#{name}")
      _not_sensitive_or_absent -> []
    end
  end

  defp country_tuples(repo, value) do
    query = from(account in Account, where: account.country == ^value, select: account.id)

    Tuples.members(rows(repo, query), "country:#{value}")
  end

  # The employment column holds one of a fixed set. A value outside that set
  # names no account, so the mapping checks the value against the set and
  # runs no query for one outside it. It reads the set from the schema at
  # run time, because a read at compile time makes this package recompile
  # whenever the example's tables change.
  defp employment_tuples(repo, value) do
    employments = Ecto.Enum.values(Account, :employment)

    case Enum.find(employments, &(to_string(&1) == value)) do
      nil -> []
      employment -> employment_members(repo, employment, value)
    end
  end

  defp employment_members(repo, employment, value) do
    query = from(account in Account, where: account.employment == ^employment, select: account.id)

    Tuples.members(rows(repo, query), "employment:#{value}")
  end

  defp repository_tuples(repo, id) do
    case row(repo, Repository, id) do
      nil -> []
      %Repository{} = repository -> carried(repo, repository, id, visibility(repo, id))
    end
  end

  defp carried(repo, %Repository{} = repository, id, visibility) do
    condition = Tuples.under_embargo(repository.embargo)

    repository_links(repository, id) ++
      directory_links(repo, id) ++
      invited(visibility, "repository:#{id}") ++
      Tuples.visibility(visibility, "repository:#{id}", condition)
  end

  defp invited(nil, _object), do: []
  defp invited(%Visibility{invited: accounts}, object), do: Tuples.invited(accounts, object)

  # What a walk reaches the access path through: the project a repository
  # belongs to and the team that owns it.
  defp repository_links(%Repository{} = repository, id) do
    links = [
      {repository.project_id, "project", "project"},
      {repository.owning_team_id, "team", "owning_team"}
    ]

    for {value, type, relation} <- links, value, do: Tuples.key("#{type}:#{value}", relation, "repository:#{id}")
  end

  defp directory_links(repo, id) do
    query = from(directory in Directory, where: directory.repository_id == ^id, select: directory.id)

    for directory <- rows(repo, query), do: Tuples.key("directory:#{directory}", "directory", "repository:#{id}")
  end

  defp directory_tuples(repo, id) do
    case row(repo, Directory, id) do
      %Directory{repository_id: nil} ->
        []

      %Directory{repository_id: repository} = directory ->
        [
          Tuples.key("repository:#{repository}", "repository", "directory:#{id}")
          | Tuples.visibility(directory, "directory:#{id}", embargo(repo, repository))
        ]

      nil ->
        []
    end
  end

  # The team that can approve, reached through the repository the proposal is
  # about, and the account that proposed, which the model subtracts.
  defp proposal_tuples(repo, id) do
    case row(repo, Proposal, id) do
      nil -> []
      %Proposal{} = proposal -> team_link(repo, id, proposal.repository_id) ++ proposer_link(id, proposal.proposer_id)
    end
  end

  defp team_link(_repo, _id, nil), do: []

  defp team_link(repo, id, repository) do
    case row(repo, Repository, repository) do
      %Repository{owning_team_id: nil} ->
        []

      %Repository{owning_team_id: team} ->
        [Tuples.key("team:#{team}", "team", "proposal:#{id}")]

      nil ->
        []
    end
  end

  defp proposer_link(_id, nil), do: []

  defp proposer_link(id, proposer), do: [Tuples.key("user:#{proposer}", "proposer", "proposal:#{id}")]

  defp visibility(repo, id) do
    query = from(visibility in Visibility, where: visibility.repository_id == ^id)

    repo.one(query, authorized_by: @exemption)
  end

  defp embargo(repo, repository) do
    case row(repo, Repository, repository) do
      nil -> nil
      %Repository{embargo: at} -> Tuples.under_embargo(at)
    end
  end

  # The rows that name the repository, which is how a date on the repository
  # reaches its directories and a change of team reaches its proposals.
  defp from_repository(repo, Directory, type, id) do
    Tuples.object(
      type,
      rows(repo, from(directory in Directory, where: directory.repository_id == ^id, select: directory.id))
    )
  end

  defp from_repository(repo, Proposal, type, id) do
    Tuples.object(type, rows(repo, from(proposal in Proposal, where: proposal.repository_id == ^id, select: proposal.id)))
  end

  # The column as the row holds it now, for a change that left it alone. A
  # delete carries its own value in the change, and a row that is gone
  # answers nothing here.
  defp held(repo, schema, id, column) do
    case row(repo, schema, id) do
      nil -> []
      found -> Enum.reject([Map.fetch!(found, column)], &is_nil/1)
    end
  end

  defp moved(changes, column) do
    case Map.fetch(changes, column) do
      {:ok, {was, now}} -> Enum.reject([was, now], &is_nil/1)
      :error -> []
    end
  end

  defp row(repo, schema, id), do: repo.get(schema, id, authorized_by: @exemption)

  defp rows(repo, query), do: repo.all(query, authorized_by: @exemption)
end
