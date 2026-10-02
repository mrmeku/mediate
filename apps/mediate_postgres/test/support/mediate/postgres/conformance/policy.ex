defmodule Mediate.Postgres.Conformance.Policy do
  @moduledoc """
  The change-management artifact of row-level security
  (`Mediate.Conformance.Policy`). `tighten/0` drops the folders' read
  rule through the owner repo and writes one that admits a reader's
  membership alone. It records a migration after the boot one, so the
  version the catalog reads moves. Then it loads the catalog again and
  releases the version. `restore/0` puts the boot rule back, takes the
  migration row out, and loads again. A rule is in force for the next
  statement, so neither waits. The rows go through the durable
  connection, which is why the case requires `durable:` beside `policy:`.
  """

  @behaviour Mediate.Conformance.Policy

  alias Mediate.Conformance.Policy
  alias Mediate.Postgres.Conformance.Reference
  alias Mediate.Postgres.Migration
  alias Mediate.Postgres.Rule
  alias Mediate.TestRepos.Owner

  @version 20_260_915_000_002
  @folders "mediate_fixture_folders"

  @impl Policy
  def tighten do
    :ok = swap!(Reference.folder_read_using("reader"))
    _result = Owner.query!("INSERT INTO schema_migrations (version, inserted_at) VALUES ($1, now())", [@version])
    _catalog = Mediate.Postgres.load_catalog!()

    release =
      Migration.release!(Owner,
        tables: Reference.tables(),
        policy_version: @version,
        author: "mediate_postgres",
        approval: "the conformance suite"
      )

    {:ok, release}
  end

  @impl Policy
  def restore do
    :ok = swap!(Reference.folder_read_using(nil))
    _result = Owner.query!("DELETE FROM schema_migrations WHERE version = $1", [@version])
    _catalog = Mediate.Postgres.load_catalog!()
    :ok
  end

  defp swap!(using) do
    _result = Owner.query!("DROP POLICY #{Rule.filter_name("read")} ON #{@folders}", [])
    Migration.filter!(Owner, table: @folders, action: :read, using: using)
  end
end
