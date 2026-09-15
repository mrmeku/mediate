defmodule Mediate.Dev.SchemaDumpTest do
  use ExUnit.Case, async: false

  alias Mediate.Dev.SchemaDump
  alias Mediate.Dev.TestRepos

  @directory "tmp/loaded_migrations"
  @output "tmp/schema/loaded.sql"

  setup do
    File.mkdir_p!(@directory)
    on_exit(fn -> File.rm_rf!(@directory) end)
    on_exit(fn -> File.rm_rf!(Path.dirname(@output)) end)
    :ok
  end

  test "a migrations directory is loaded once and run on every database of the cluster" do
    File.write!(Path.join(@directory, "20260908000001_accounts.exs"), """
    defmodule Mediate.Dev.LoadedMigration do
      use Ecto.Migration

      def up, do: execute("CREATE TABLE mediate_dev_loaded (id bigserial PRIMARY KEY)")
      def down, do: execute("DROP TABLE mediate_dev_loaded")
    end
    """)

    assert SchemaDump.dump(repo: TestRepos.Dump, output: @output, migrations: @directory) == @output
    assert File.read!(@output) =~ "CREATE TABLE public.mediate_dev_loaded"
    assert Code.ensure_loaded?(Mediate.Dev.LoadedMigration)
  end
end
