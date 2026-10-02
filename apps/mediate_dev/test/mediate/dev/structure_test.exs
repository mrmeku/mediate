defmodule Mediate.Dev.StructureTest do
  use ExUnit.Case, async: false

  alias Mediate.Dev.Structure
  alias Mediate.Dev.TestRepos

  @directory "tmp/loaded_migrations"
  @structure_file "tmp/schema/loaded.sql"

  setup do
    File.mkdir_p!(@directory)
    on_exit(fn -> File.rm_rf!(@directory) end)
    on_exit(fn -> File.rm_rf!(Path.dirname(@structure_file)) end)
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

    assert Structure.dump(repo: TestRepos.Dump, file: @structure_file, migrations: @directory) == @structure_file
    assert File.read!(@structure_file) =~ "CREATE TABLE public.mediate_dev_loaded"
    assert Code.ensure_loaded?(Mediate.Dev.LoadedMigration)
  end
end
