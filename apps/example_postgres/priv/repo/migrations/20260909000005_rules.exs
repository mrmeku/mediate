defmodule ExamplePostgres.Repo.Migrations.Rules do
  @moduledoc false
  use Ecto.Migration

  alias ExamplePostgres.Infrastructure.Policies
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Migration

  @version 20_260_909_000_005
  @app Policies.app_role()
  @owner Policies.owner_role()
  @repositories "repositories"
  @visibilities "visibilities"
  @directories "directories"
  @proposals "visibility_proposals"

  def up do
    repo = repo()
    Enum.each(Policies.protected(), &execute("ALTER TABLE #{&1} OWNER TO #{@owner}"))
    Enum.each(Policies.accessors(), &execute/1)
    flush()
    Enum.each(Policies.protected(), &Migration.protect!(repo, &1))
    repositories(repo)
    visibilities(repo)
    directories(repo)
    proposals(repo)
    :ok = Migration.grant!(repo, table: "schema_migrations", to: @app, commands: [:select])
    _version = Migration.publish!(repo, published())
    :ok
  end

  def down do
    repo = repo()
    Enum.each(Catalog.policies!(repo, Policies.protected()), &execute("DROP POLICY #{&1.name} ON #{&1.table}"))
    Enum.each(Policies.protected(), &execute("ALTER TABLE #{&1} NO FORCE ROW LEVEL SECURITY"))
    Enum.each(Policies.protected(), &execute("ALTER TABLE #{&1} DISABLE ROW LEVEL SECURITY"))
    Enum.each(Policies.accessor_drops(), &execute/1)
    execute("REVOKE SELECT ON schema_migrations FROM #{@app}")
    :ok
  end

  # A repository answers `read` under every rule and `checkout` under
  # access path alone; the visibility operations reach it through the
  # owning team, and the three that write it carry the gate as well.
  defp repositories(repo) do
    scope(repo, @repositories, :read, Policies.repository_read(Policies.readers()))
    scope(repo, @repositories, :checkout, Policies.repository_checkout())
    writes = [:change_visibility, :set_embargo, :lift_embargo]
    Enum.each(writes, &scope(repo, @repositories, &1, Policies.repository_visibility()))
    scope(repo, @repositories, :propose_visibility, Policies.repository_admin())
    scope(repo, @repositories, :approve_visibility, Policies.repository_reviewer())
    Enum.each(writes, &gate(repo, @repositories, &1, Policies.repository_visibility()))
    exempt(repo, @repositories, [:select, :insert])
  end

  # The rollup is reached through its repository, whose policy is what admits
  # the read, so every read of a visibility is admitted here and the two write
  # gates are what the table enforces: the admin's change, and the
  # approval of somebody else's proposal.
  defp visibilities(repo) do
    :ok = Migration.admit!(repo, table: @visibilities, command: :select)
    gate(repo, @visibilities, :change_visibility, Policies.visibility_write())
    gate(repo, @visibilities, :approve_visibility, Policies.visibility_approval())
    :ok = Migration.exempt!(repo, table: @visibilities, to: @app, commands: [:insert, :update])
  end

  defp directories(repo) do
    scope(repo, @directories, :read, Policies.directory_read())
    scope(repo, @directories, :change_visibility, Policies.directory_visibility())
    gate(repo, @directories, :change_visibility, Policies.directory_visibility())
    exempt(repo, @directories, [:select, :insert])
  end

  defp proposals(repo) do
    scope(repo, @proposals, :propose_visibility, Policies.proposal_proposer())
    scope(repo, @proposals, :approve_visibility, Policies.proposal_reviewer())
    gate(repo, @proposals, :approve_visibility, Policies.proposal_reviewer())

    :ok =
      Migration.gate!(repo,
        table: @proposals,
        operation: :propose_visibility,
        command: :insert,
        with_check: Policies.proposal_written()
      )

    exempt(repo, @proposals, [:select])
  end

  defp scope(repo, table, operation, using) do
    :ok = Migration.policy!(repo, table: table, operation: operation, using: using)
  end

  # The gate reads `true` before the write, so the row is there for the
  # database to apply `WITH CHECK` to and a write that violates the rule is
  # refused rather than silently matching nothing.
  defp gate(repo, table, operation, with_check) do
    :ok = Migration.gate!(repo, table: table, operation: operation, using: "true", with_check: with_check)
  end

  # The application's own statements outside a decision, which is what the
  # seam leaves behind when it admits a call under a declared exemption,
  # and the owner's reads, which the accessor functions and the truncation
  # between committed tests run under.
  defp exempt(repo, table, commands) do
    :ok = Migration.exempt!(repo, table: table, to: @app, commands: commands)
    :ok = Migration.exempt!(repo, table: table, to: @owner, commands: [:select], outside_decision: false)
  end

  defp published do
    [tables: Policies.protected()] ++ ExamplePostgres.published(to_string(@version))
  end
end
