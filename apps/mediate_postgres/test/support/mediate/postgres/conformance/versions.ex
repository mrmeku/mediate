defmodule Mediate.Postgres.Conformance.Versions do
  @moduledoc """
  The change-management artifact of row-level security.
  `Mediate.Conformance.Versions` has the callbacks.

  `tighten/0` drops the folders' read policy through the owner repo and
  writes one that admits a reader's membership alone. It records a
  migration after the boot one, so the version the catalog reads moves.
  Then it reloads the catalog and publishes the version.

  `restore/0` puts the boot policy back, takes the migration row out, and
  reloads. A policy is in force for the next statement, so neither waits.
  The rows go through the committed connection, which is why the template
  requires `committed:` beside `versions:`.
  """

  @behaviour Mediate.Conformance.Versions

  alias Mediate.Conformance.Versions
  alias Mediate.Postgres.Conformance.Rules
  alias Mediate.Postgres.Migration
  alias Mediate.Postgres.Policy
  alias Mediate.Postgres.Version
  alias Mediate.TestRepos.Owner

  @version 20_260_915_000_002
  @folders "mediate_fixture_folders"

  @impl Versions
  def event, do: Version.telemetry_event()

  @impl Versions
  def tighten do
    :ok = swap!(Rules.folder_read("reader"))
    _result = Owner.query!("INSERT INTO schema_migrations (version, inserted_at) VALUES ($1, now())", [@version])
    _catalog = Mediate.Postgres.reload!()

    version =
      Migration.publish!(Owner,
        tables: Rules.tables(),
        version: @version,
        author: "mediate_postgres",
        approval: "the conformance suite"
      )

    {:ok, version}
  end

  @impl Versions
  def restore do
    :ok = swap!(Rules.folder_read(nil))
    _result = Owner.query!("DELETE FROM schema_migrations WHERE version = $1", [@version])
    _catalog = Mediate.Postgres.reload!()
    :ok
  end

  defp swap!(using) do
    _result = Owner.query!("DROP POLICY #{Policy.scope_name("read")} ON #{@folders}", [])
    Migration.policy!(Owner, table: @folders, operation: :read, using: using)
  end
end
