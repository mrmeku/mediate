defmodule Mediate.Fga.MigrationCommittedTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL
  alias Mediate.Fga.TestMigrations.Outbox
  alias Mediate.TestRepos.Owner

  @moduletag :committed

  @outbox "SELECT to_regclass('mediate_fga_outbox') IS NOT NULL"
  @cursor "SELECT to_regclass('mediate_relay_cursor') IS NOT NULL"

  test "the outbox and cursor tables the helpers raise can be taken back down and raised again" do
    assert Ecto.Migrator.run(Owner, [{1, Outbox}], :down, all: true, log: false) == [1]
    assert %{rows: [[false]]} = SQL.query!(Owner, @outbox)
    assert %{rows: [[false]]} = SQL.query!(Owner, @cursor)

    assert Ecto.Migrator.run(Owner, [{1, Outbox}], :up, all: true, log: false) == [1]
    assert %{rows: [[true]]} = SQL.query!(Owner, @outbox)
    assert %{rows: [[true]]} = SQL.query!(Owner, @cursor)
    assert %{rows: []} = SQL.query!(Owner, "SELECT id, object FROM mediate_fga_outbox")
    assert %{rows: []} = SQL.query!(Owner, "SELECT name, position FROM mediate_relay_cursor")
  end
end
