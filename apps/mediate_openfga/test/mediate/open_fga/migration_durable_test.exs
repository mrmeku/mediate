defmodule Mediate.OpenFGA.MigrationDurableTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL
  alias Mediate.OpenFGA.TestMigrations.Outbox
  alias Mediate.TestRepos.Owner

  @moduletag :durable

  @outbox "SELECT to_regclass('mediate_openfga_outbox') IS NOT NULL"
  @cursor "SELECT to_regclass('mediate_relay_cursor') IS NOT NULL"

  test "the outbox and cursor tables the migrations create can be taken back down and created again" do
    assert Ecto.Migrator.run(Owner, [{1, Outbox}], :down, all: true, log: false) == [1]
    assert %{rows: [[false]]} = SQL.query!(Owner, @outbox)
    assert %{rows: [[false]]} = SQL.query!(Owner, @cursor)

    assert Ecto.Migrator.run(Owner, [{1, Outbox}], :up, all: true, log: false) == [1]
    assert %{rows: [[true]]} = SQL.query!(Owner, @outbox)
    assert %{rows: [[true]]} = SQL.query!(Owner, @cursor)
    assert %{rows: []} = SQL.query!(Owner, "SELECT id, object FROM mediate_openfga_outbox")
    assert %{rows: []} = SQL.query!(Owner, "SELECT name, position FROM mediate_relay_cursor")
  end
end
