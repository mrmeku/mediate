defmodule Mediate.Dev.TestMigration do
  @moduledoc """
  One table as a migration. The cluster runs it on each of its databases,
  and the schema-dump test writes it out. The owner role owns the table, and
  the application role can read and write its rows.
  """

  use Boundary, top_level?: true, deps: [Ecto.Migration]
  use Ecto.Migration

  @table "mediate_dev_rows"

  @doc "Create the table and the application role's grant."
  @spec up() :: :ok
  def up do
    execute("CREATE TABLE #{@table} (id bigserial PRIMARY KEY, name text)")
    execute("GRANT SELECT, INSERT, UPDATE, DELETE ON #{@table} TO mediate_app")
    execute("GRANT USAGE, SELECT ON SEQUENCE #{@table}_id_seq TO mediate_app")
  end

  @doc "Drop it."
  @spec down() :: :ok
  def down, do: execute("DROP TABLE #{@table}")
end
