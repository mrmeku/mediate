defmodule ExamplePostgres.Migrations.Policy do
  @moduledoc false
  use Ecto.Migration

  alias ExamplePostgres.Infrastructure.Policy
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Migration

  @version 20_260_909_000_005
  @app Policy.app_role()
  @owner Policy.owner_role()
  @repositories "repositories"
  @visibilities "visibilities"
  @directories "directories"
  @proposals "proposals"

  def up do
    repo = repo()
    Enum.each(Policy.protected_tables(), &execute("ALTER TABLE #{&1} OWNER TO #{@owner}"))
    Enum.each(Policy.lookup_functions(), &execute/1)
    flush()
    Enum.each(Policy.protected_tables(), &Migration.protect!(repo, &1))
    repositories(repo)
    visibilities(repo)
    directories(repo)
    proposals(repo)
    :ok = Migration.privileges!(repo, table: "schema_migrations", to: @app, commands: [:select])
    _release = Migration.release!(repo, release_options())
    :ok
  end

  def down do
    repo = repo()
    Enum.each(Catalog.rules(repo, Policy.protected_tables()), &execute("DROP POLICY #{&1.name} ON #{&1.table}"))
    Enum.each(Policy.protected_tables(), &execute("ALTER TABLE #{&1} NO FORCE ROW LEVEL SECURITY"))
    Enum.each(Policy.protected_tables(), &execute("ALTER TABLE #{&1} DISABLE ROW LEVEL SECURITY"))
    Enum.each(Policy.lookup_drops(), &execute/1)
    execute("REVOKE SELECT ON schema_migrations FROM #{@app}")
    :ok
  end

  # A repository answers `read` under every clause and `checkout` under the
  # access path alone; the visibility actions reach it through the owning
  # team, and the three that write it carry the gate rule as well.
  defp repositories(repo) do
    filter(repo, @repositories, :read, Policy.repository_read())
    filter(repo, @repositories, :checkout, Policy.repository_checkout())
    writes = [:change_visibility, :set_embargo, :lift_embargo]
    Enum.each(writes, &filter(repo, @repositories, &1, Policy.admin_in_fresh_session()))
    filter(repo, @repositories, :propose_visibility, Policy.admin_of_owning_team())
    filter(repo, @repositories, :approve_visibility, Policy.reviewer_of_owning_team())
    Enum.each(writes, &gate(repo, @repositories, &1, Policy.admin_in_fresh_session()))
    exempt(repo, @repositories, [:select, :insert])
  end

  # The rollup is reached through its repository, whose filter rule narrows
  # the read, so an admit rule admits every read of a visibility and the two
  # gate rules are what the table enforces: the admin's change, and the
  # approval of somebody else's proposal.
  defp visibilities(repo) do
    :ok = Migration.admit!(repo, table: @visibilities, command: :select)
    gate(repo, @visibilities, :change_visibility, Policy.change_visibility_check())
    gate(repo, @visibilities, :approve_visibility, Policy.approve_visibility_check())
    :ok = Migration.exempt!(repo, table: @visibilities, to: @app, commands: [:insert, :update])
  end

  defp directories(repo) do
    filter(repo, @directories, :read, Policy.directory_read())
    filter(repo, @directories, :change_visibility, Policy.directory_change_visibility())
    gate(repo, @directories, :change_visibility, Policy.directory_change_visibility())
    exempt(repo, @directories, [:select, :insert])
  end

  defp proposals(repo) do
    filter(repo, @proposals, :propose_visibility, Policy.proposal_propose_visibility())
    filter(repo, @proposals, :approve_visibility, Policy.proposal_approve_visibility())
    gate(repo, @proposals, :approve_visibility, Policy.proposal_approve_visibility())

    :ok =
      Migration.gate!(repo,
        table: @proposals,
        action: :propose_visibility,
        command: :insert,
        with_check: Policy.proposal_propose_visibility_check()
      )

    exempt(repo, @proposals, [:select])
  end

  defp filter(repo, table, action, using) do
    :ok = Migration.filter!(repo, table: table, action: action, using: using)
  end

  # The gate rule reads `true` before the write, so the row is there for the
  # database to apply `WITH CHECK` to, and a write that breaks the clause is
  # refused rather than matching nothing.
  defp gate(repo, table, action, with_check) do
    :ok = Migration.gate!(repo, table: table, action: action, using: "true", with_check: with_check)
  end

  # The application role's own statements outside a decision, which is what
  # the mediated repo leaves behind when it admits a call under a declared
  # exemption, and the owner role's reads, which the lookup functions and
  # the truncation between durable tests run under.
  defp exempt(repo, table, commands) do
    :ok = Migration.exempt!(repo, table: table, to: @app, commands: commands)
    :ok = Migration.exempt!(repo, table: table, to: @owner, commands: [:select], always: true)
  end

  defp release_options do
    [
      tables: Policy.protected_tables(),
      policy_version: to_string(@version),
      author: ExamplePostgres.author(),
      approval: ExamplePostgres.approval(),
      policy_text_bytes: ExamplePostgres.policy_text_bytes()
    ]
  end
end
