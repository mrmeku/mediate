defmodule ExamplePostgres.Infrastructure.Policies do
  @moduledoc """
  The example's rules as Postgres policy expressions. `docs/example.md`
  states the rules. Each function answers one SQL fragment, and the rules
  migration hands those fragments to `Mediate.Postgres.Migration`. A
  fragment reads every fact from the tables at the moment the statement
  runs. So a revoked row grants nothing at the next statement.

  The subject and the moment come from the session settings
  `Mediate.Postgres` sets around every call. The fragments read three:
  `mediate.subject_id`, `mediate.now`, and `mediate.reauthenticated_at`, a
  fact the caller supplies. A setting the caller did not supply reads as
  `NULL`. A predicate over `NULL` is not true, so an absent fact denies.

  A policy on `directories` reads its repository's project, owning team,
  and embargo date through the accessor functions, not through
  `repositories`. Under the `read` operation the repository's own policy narrows
  every reference to that table. Through `repositories`, a directory of a
  repository the rollup blocks disappears with its repository. The accessors run
  as the table's owner, whose reads the owner's exemption policy admits. So
  the directory answers under its own visibility.
  """

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

  @app_role "mediate_app"
  @owner_role "mediate_owner"

  @subject "current_setting('mediate.subject_id', true)"
  @now "nullif(current_setting('mediate.now', true), '')::timestamp"
  @reauthenticated "nullif(current_setting('mediate.reauthenticated_at', true), '')::timestamp"
  @window "interval '900 seconds'"
  @fresh "(#{@now} - #{@reauthenticated}) BETWEEN interval '0 second' AND #{@window}"

  @project "mediate_repository_project"
  @team "mediate_repository_owning_team"
  @embargo "mediate_repository_embargo"

  @accessors [
    {@project, "bigint", "project_id"},
    {@team, "bigint", "owning_team_id"},
    {@embargo, "timestamp", "embargo"}
  ]

  @restrictions ~w(employees_only export_controlled releasable_to invite_only)
  @readers ~w(maintainer contributor)
  @admin ~w(admin)
  @reviewer ~w(reviewer)
  @team_readers ~w(admin reviewer)

  @doc "The tables the policies protect. A published version carries the policies of these tables."
  @spec protected() :: [String.t()]
  def protected, do: ~w(repositories visibilities directories visibility_proposals)

  @doc """
  The schemas the binding names: the four whose tables the policies
  protect, and the seven whose tables the policies read. So every column a
  policy reads meets a declaration in the coverage check.
  """
  @spec schemas() :: [module()]
  def schemas do
    [Repository, Visibility, Directory, Proposal, Enterprise, Membership, Label, Team, TeamRole, Project, User]
  end

  @doc "The database role the application connects as."
  @spec app_role() :: String.t()
  def app_role, do: @app_role

  @doc "The database role that owns the protected tables and runs the migrations."
  @spec owner_role() :: String.t()
  def owner_role, do: @owner_role

  @doc "The membership roles that reach a repository at all, which is every one of them."
  @spec readers() :: [String.t()]
  def readers, do: @readers

  @doc "The accessor functions a policy on `directories` reads its repository through, with their grants."
  @spec accessors() :: [String.t()]
  def accessors, do: Enum.flat_map(@accessors, &accessor/1)

  @doc "The `DROP` statements of the same functions."
  @spec accessor_drops() :: [String.t()]
  def accessor_drops, do: Enum.map(@accessors, fn {name, _type, _column} -> "DROP FUNCTION #{name}(bigint)" end)

  @doc "The `SELECT` policy of `read` on `repositories`, for the membership roles that hold it."
  @spec repository_read([String.t()]) :: String.t()
  def repository_read(roles) when is_list(roles) do
    "(#{repository_access_path(roles)}) AND NOT (#{repository_blocked()})"
  end

  @doc "The `SELECT` policy of `checkout` on `repositories`: access path alone."
  @spec repository_checkout() :: String.t()
  def repository_checkout, do: repository_access_path(@readers)

  @doc "An admin of the owning team."
  @spec repository_admin() :: String.t()
  def repository_admin, do: holds("repositories.owning_team_id", @admin)

  @doc "A reviewer of the owning team."
  @spec repository_reviewer() :: String.t()
  def repository_reviewer, do: holds("repositories.owning_team_id", @reviewer)

  @doc "An admin of the owning team in a session that re-authenticated inside the window."
  @spec repository_visibility() :: String.t()
  def repository_visibility, do: "(#{repository_admin()}) AND (#{@fresh})"

  @doc "The `SELECT` policy of `read` on `directories`: the repository's access path and the directory's own visibility."
  @spec directory_read() :: String.t()
  def directory_read, do: "(#{directory_access_path()}) AND NOT (#{directory_blocked()})"

  @doc "An admin of the directory's repository's team in a fresh session."
  @spec directory_visibility() :: String.t()
  def directory_visibility do
    "(#{holds("#{@team}(directories.repository_id)", @admin)}) AND (#{@fresh})"
  end

  @doc "An admin of the repository's team, the subject that can propose."
  @spec proposal_proposer() :: String.t()
  def proposal_proposer, do: holds("#{@team}(visibility_proposals.repository_id)", @admin)

  @doc "A reviewer of the repository's team who is not the proposer."
  @spec proposal_reviewer() :: String.t()
  def proposal_reviewer do
    reviewer = holds("#{@team}(visibility_proposals.repository_id)", @reviewer)
    "(#{reviewer}) AND visibility_proposals.proposer_id <> #{@subject}"
  end

  @doc "The row a proposal insert can write: the subject's own, on a repository the subject names."
  @spec proposal_written() :: String.t()
  def proposal_written do
    "(#{proposal_proposer()}) AND visibility_proposals.proposer_id = #{@subject}"
  end

  @doc "The rollup an admin can write in a fresh session."
  @spec visibility_write() :: String.t()
  def visibility_write do
    "(#{holds("#{@team}(visibilities.repository_id)", @admin)}) AND (#{@fresh})"
  end

  @doc """
  The rollup an approval can write: a reviewer of the repository's team
  writes it, and a pending proposal on that repository from somebody else
  exists. The approval writes the proposal's own row after its repository's,
  so at this moment the proposal is still pending.
  """
  @spec visibility_approval() :: String.t()
  def visibility_approval do
    reviewer = holds("#{@team}(visibilities.repository_id)", @reviewer)

    """
    (#{reviewer}) AND EXISTS (
      SELECT 1 FROM visibility_proposals p
      WHERE p.repository_id = visibilities.repository_id
        AND p.status = 'pending'
        AND p.proposer_id <> #{@subject}
    )
    """
  end

  defp accessor({name, type, column}) do
    [
      """
      CREATE FUNCTION #{name}(repository bigint) RETURNS #{type}
        LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
        AS 'SELECT #{column} FROM repositories WHERE id = repository'
      """,
      "REVOKE EXECUTE ON FUNCTION #{name}(bigint) FROM PUBLIC",
      "GRANT EXECUTE ON FUNCTION #{name}(bigint) TO #{@app_role}, #{@owner_role}"
    ]
  end

  # Access path: a membership to the repository's project while that
  # project is not archived, or a role in the team that owns it.
  defp repository_access_path(roles) do
    "#{assigned("repositories.project_id", roles)} OR #{holds("repositories.owning_team_id", @team_readers)}"
  end

  defp directory_access_path do
    assigned = assigned("#{@project}(directories.repository_id)", @readers)
    "#{assigned} OR #{holds("#{@team}(directories.repository_id)", @team_readers)}"
  end

  defp assigned(project, roles) do
    """
    EXISTS (
      SELECT 1 FROM memberships a
      JOIN projects p ON p.id = a.project_id
      WHERE a.user_id = #{@subject}
        AND a.project_id = #{project}
        AND a.role = ANY (ARRAY[#{quoted(roles)}])
        AND p.archived_at IS NULL
    )
    """
  end

  defp holds(team, roles) do
    """
    EXISTS (
      SELECT 1 FROM team_roles r
      WHERE r.user_id = #{@subject}
        AND r.team_id = #{team}
        AND r.role = ANY (ARRAY[#{quoted(roles)}])
    )
    """
  end

  # Until the repository's embargo date, an effective restriction of its rollup
  # that the subject does not clear.
  defp repository_blocked do
    """
    EXISTS (
      SELECT 1
      FROM visibilities m
      JOIN teams o ON o.id = repositories.owning_team_id
      JOIN enterprises g ON g.id = o.enterprise_id
      JOIN users u ON u.id = #{@subject}
      LEFT JOIN labels c ON c.name = ANY (m.labels) AND c.sensitive
      WHERE m.repository_id = repositories.id
        AND (repositories.embargo IS NULL OR repositories.embargo > #{@now})
        AND (#{fails("m", "m")})
    )
    """
  end

  # The same on a directory: its own restrictions and labels, under its
  # repository's list and embargo date.
  defp directory_blocked do
    """
    EXISTS (
      SELECT 1
      FROM visibilities dm
      JOIN teams o ON o.id = #{@team}(directories.repository_id)
      JOIN enterprises g ON g.id = o.enterprise_id
      JOIN users u ON u.id = #{@subject}
      LEFT JOIN labels c ON c.name = ANY (directories.labels) AND c.sensitive
      WHERE dm.repository_id = directories.repository_id
        AND (#{@embargo}(directories.repository_id) IS NULL OR #{@embargo}(directories.repository_id) > #{@now})
        AND (#{fails("directories", "dm")})
    )
    """
  end

  defp fails(visibility, invited) do
    Enum.map_join(@restrictions, " OR ", &"(#{effective(&1, visibility)} AND #{test(&1, visibility, invited)})")
  end

  defp test("employees_only", _visibility, _invited), do: "u.employment <> 'employee'"
  defp test("export_controlled", _visibility, _invited), do: "u.country <> g.country"
  defp test("releasable_to", visibility, _invited), do: "NOT (u.country = ANY (#{visibility}.releasable_to))"
  defp test("invite_only", _visibility, invited), do: "NOT (#{@subject} = ANY (#{invited}.invited))"

  # A restriction is effective when the visibility declares it or a sensitive
  # label the visibility names implies it. The policy copies nothing.
  defp effective(restriction, visibility) do
    "('#{restriction}' = ANY (#{visibility}.restrictions) OR '#{restriction}' = ANY (c.implied_restrictions))"
  end

  defp quoted(values), do: Enum.map_join(values, ", ", &"'#{&1}'")
end
