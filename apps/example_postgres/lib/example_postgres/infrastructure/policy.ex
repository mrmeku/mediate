defmodule ExamplePostgres.Infrastructure.Policy do
  @moduledoc """
  The example's clauses as the expressions of Postgres rules.
  `docs/example.md` states the clauses. Each function answers the `USING` or
  `WITH CHECK` expression of one rule, and the policy migration hands it to
  `Mediate.Postgres.Migration`. An expression reads every fact from the
  tables at the moment the statement runs. So a revoked row grants nothing
  at the next statement.

  The subject and the moment come from the settings `Mediate.Postgres` sets
  around every call. The expressions read three: `mediate.subject_id`,
  `mediate.now`, and `mediate.reauthenticated_at`, a context fact the caller
  supplies. A setting the caller did not supply reads as `NULL`. An
  expression over `NULL` is not true, so an absent fact denies.

  A rule on `directories` reads its repository's project, owning team, and
  embargo through the lookup functions, not through `repositories`. Under
  the `read` action the repository's own filter rule narrows every reference
  to that table. Through `repositories`, a directory of a repository the
  rollup blocks disappears with its repository. A lookup function runs as
  the table's owner, `SECURITY DEFINER`, whose reads the owner role's exempt
  rule admits. So the directory answers under its own visibility.
  """

  alias Example.Domain.Account
  alias Example.Domain.Directory
  alias Example.Domain.Enterprise
  alias Example.Domain.Label
  alias Example.Domain.Membership
  alias Example.Domain.Project
  alias Example.Domain.Proposal
  alias Example.Domain.Reauthentication
  alias Example.Domain.Repository
  alias Example.Domain.Restrictions
  alias Example.Domain.Team
  alias Example.Domain.TeamRole
  alias Example.Domain.Visibility

  @app_role "mediate_app"
  @owner_role "mediate_owner"

  @subject_id "current_setting('mediate.subject_id', true)"
  @now "nullif(current_setting('mediate.now', true), '')::timestamp"
  @reauthenticated_at "nullif(current_setting('mediate.reauthenticated_at', true), '')::timestamp"
  @reauthentication_window "interval '#{Reauthentication.window()} seconds'"
  @fresh_session "(#{@now} - #{@reauthenticated_at}) BETWEEN interval '0 second' AND #{@reauthentication_window}"

  @repository_project "example_repository_project"
  @repository_owning_team "example_repository_owning_team"
  @repository_embargo "example_repository_embargo"

  @lookup_functions [
    {@repository_project, "bigint", "project_id"},
    {@repository_owning_team, "bigint", "owning_team_id"},
    {@repository_embargo, "timestamp", "embargo"}
  ]

  @reader_roles ~w(maintainer contributor)
  @admin ~w(admin)
  @reviewer ~w(reviewer)
  @team_reader_roles ~w(admin reviewer)

  @doc "The tables the rules protect. The policy release carries the rules of these tables."
  @spec protected_tables() :: [String.t()]
  def protected_tables, do: ~w(repositories visibilities directories proposals)

  @doc """
  The schemas the binding names: the four whose tables the rules protect,
  and the seven whose tables the rules read. So every column a rule reads
  meets a declaration in the declared-facts check.
  """
  @spec schemas() :: [module()]
  def schemas do
    [Repository, Visibility, Directory, Proposal, Enterprise, Membership, Label, Team, TeamRole, Project, Account]
  end

  @doc "The database role the application connects as."
  @spec app_role() :: String.t()
  def app_role, do: @app_role

  @doc "The database role that owns the protected tables and runs the migrations."
  @spec owner_role() :: String.t()
  def owner_role, do: @owner_role

  @doc "The membership roles that reach a repository at all, which is every one of them."
  @spec reader_roles() :: [String.t()]
  def reader_roles, do: @reader_roles

  @doc "The lookup functions a rule on `directories` reads its repository through, with their grants."
  @spec lookup_functions() :: [String.t()]
  def lookup_functions, do: Enum.flat_map(@lookup_functions, &lookup_function/1)

  @doc "The `DROP` statements of the same functions."
  @spec lookup_drops() :: [String.t()]
  def lookup_drops, do: Enum.map(@lookup_functions, fn {name, _type, _column} -> "DROP FUNCTION #{name}(bigint)" end)

  @doc "The filter rule of `read` on `repositories`: the access path, and no restriction blocks the subject."
  @spec repository_read() :: String.t()
  def repository_read, do: "(#{repository_access_path(@reader_roles)}) AND NOT (#{repository_blocked()})"

  @doc "The filter rule of `checkout` on `repositories`: the access path alone."
  @spec repository_checkout() :: String.t()
  def repository_checkout, do: repository_access_path(@reader_roles)

  @doc "An admin of the repository's owning team."
  @spec admin_of_owning_team() :: String.t()
  def admin_of_owning_team, do: team_role("repositories.owning_team_id", @admin)

  @doc "A reviewer of the repository's owning team."
  @spec reviewer_of_owning_team() :: String.t()
  def reviewer_of_owning_team, do: team_role("repositories.owning_team_id", @reviewer)

  @doc "An admin of the repository's owning team in a fresh session: the three visibility writes on `repositories`."
  @spec admin_in_fresh_session() :: String.t()
  def admin_in_fresh_session, do: "(#{admin_of_owning_team()}) AND (#{@fresh_session})"

  @doc "The filter rule of `read` on `directories`: the repository's access path, and the directory's own visibility."
  @spec directory_read() :: String.t()
  def directory_read, do: "(#{directory_access_path()}) AND NOT (#{directory_blocked()})"

  @doc "The two rules of `change_visibility` on `directories`: an admin of the owning team in a fresh session."
  @spec directory_change_visibility() :: String.t()
  def directory_change_visibility do
    "(#{team_role("#{@repository_owning_team}(directories.repository_id)", @admin)}) AND (#{@fresh_session})"
  end

  @doc "The filter rule of `propose_visibility` on `proposals`: an admin of the repository's owning team."
  @spec proposal_propose_visibility() :: String.t()
  def proposal_propose_visibility, do: team_role("#{@repository_owning_team}(proposals.repository_id)", @admin)

  @doc "The two rules of `approve_visibility` on `proposals`: a reviewer of the owning team who is not the proposer."
  @spec proposal_approve_visibility() :: String.t()
  def proposal_approve_visibility do
    reviewer = team_role("#{@repository_owning_team}(proposals.repository_id)", @reviewer)
    "(#{reviewer}) AND proposals.proposer_id <> #{@subject_id}"
  end

  @doc "The gate rule of `propose_visibility` on `proposals`: the row an insert writes is the subject's own."
  @spec proposal_propose_visibility_check() :: String.t()
  def proposal_propose_visibility_check do
    "(#{proposal_propose_visibility()}) AND proposals.proposer_id = #{@subject_id}"
  end

  @doc "The gate rule of `change_visibility` on `visibilities`: the rollup an admin writes in a fresh session."
  @spec change_visibility_check() :: String.t()
  def change_visibility_check do
    "(#{team_role("#{@repository_owning_team}(visibilities.repository_id)", @admin)}) AND (#{@fresh_session})"
  end

  @doc """
  The gate rule of `approve_visibility` on `visibilities`: the rollup an
  approval writes. A reviewer of the repository's owning team writes it, and
  a pending proposal on that repository from somebody else exists. The
  approval writes the proposal's own row after its repository's, so at this
  moment the proposal is still pending.
  """
  @spec approve_visibility_check() :: String.t()
  def approve_visibility_check do
    reviewer = team_role("#{@repository_owning_team}(visibilities.repository_id)", @reviewer)

    """
    (#{reviewer}) AND EXISTS (
      SELECT 1 FROM proposals p
      WHERE p.repository_id = visibilities.repository_id
        AND p.status = 'pending'
        AND p.proposer_id <> #{@subject_id}
    )
    """
  end

  defp lookup_function({name, type, column}) do
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

  # The access path: a membership to the repository's project while that
  # project is not archived, or a team role in the team that owns it.
  defp repository_access_path(roles) do
    "#{membership("repositories.project_id", roles)} OR #{team_role("repositories.owning_team_id", @team_reader_roles)}"
  end

  defp directory_access_path do
    membership = membership("#{@repository_project}(directories.repository_id)", @reader_roles)
    team_role = team_role("#{@repository_owning_team}(directories.repository_id)", @team_reader_roles)
    "#{membership} OR #{team_role}"
  end

  defp membership(project, roles) do
    """
    EXISTS (
      SELECT 1 FROM memberships m
      JOIN projects p ON p.id = m.project_id
      WHERE m.account_id = #{@subject_id}
        AND m.project_id = #{project}
        AND m.role = ANY (ARRAY[#{literals(roles)}])
        AND p.archived_at IS NULL
    )
    """
  end

  defp team_role(team, roles) do
    """
    EXISTS (
      SELECT 1 FROM team_roles r
      WHERE r.account_id = #{@subject_id}
        AND r.team_id = #{team}
        AND r.role = ANY (ARRAY[#{literals(roles)}])
    )
    """
  end

  # Until the repository's embargo lifts, a kind in effect for its rollup
  # that blocks the subject.
  defp repository_blocked do
    """
    EXISTS (
      SELECT 1
      FROM visibilities v
      JOIN teams t ON t.id = repositories.owning_team_id
      JOIN enterprises e ON e.id = t.enterprise_id
      JOIN accounts a ON a.id = #{@subject_id}
      LEFT JOIN labels l ON l.name = ANY (v.labels) AND l.sensitive
      WHERE v.repository_id = repositories.id
        AND (repositories.embargo IS NULL OR repositories.embargo > #{@now})
        AND (#{blocked("v", "v")})
    )
    """
  end

  # The same on a directory: its own restrictions and labels, under its
  # repository's invited list and embargo.
  defp directory_blocked do
    embargo = "#{@repository_embargo}(directories.repository_id)"

    """
    EXISTS (
      SELECT 1
      FROM visibilities v
      JOIN teams t ON t.id = #{@repository_owning_team}(directories.repository_id)
      JOIN enterprises e ON e.id = t.enterprise_id
      JOIN accounts a ON a.id = #{@subject_id}
      LEFT JOIN labels l ON l.name = ANY (directories.labels) AND l.sensitive
      WHERE v.repository_id = directories.repository_id
        AND (#{embargo} IS NULL OR #{embargo} > #{@now})
        AND (#{blocked("directories", "v")})
    )
    """
  end

  # The `or` of every kind: in effect for the visibility, and blocking the
  # subject.
  defp blocked(visibility, invited_list) do
    Enum.map_join(Restrictions.kinds(), " OR ", fn kind ->
      "(#{in_effect(kind, visibility)} AND #{blocks(kind, visibility, invited_list)})"
    end)
  end

  defp blocks(:employees_only, _visibility, _invited_list), do: "a.employment <> 'employee'"
  defp blocks(:export_controlled, _visibility, _invited_list), do: "a.country <> e.country"
  defp blocks(:releasable_to, visibility, _invited_list), do: "NOT (a.country = ANY (#{visibility}.releasable_to))"
  defp blocks(:invite_only, _visibility, invited_list), do: "NOT (#{@subject_id} = ANY (#{invited_list}.invited))"

  # A kind is in effect when the visibility declares it or a sensitive label
  # the visibility names implies it. The rule copies nothing.
  defp in_effect(kind, visibility) do
    "('#{kind}' = ANY (#{visibility}.restrictions) OR '#{kind}' = ANY (l.implied_restrictions))"
  end

  defp literals(values), do: Enum.map_join(values, ", ", &"'#{&1}'")
end
