defmodule Mix.Tasks.Mediate.DumpTest do
  use ExUnit.Case, async: false

  alias Mediate.Dev.Structure
  alias Mediate.Dev.TestRepos
  alias Mix.Tasks.Mediate.Dump

  @structure_file "tmp/schema/dev.sql"

  setup do
    File.rm_rf!(Path.dirname(@structure_file))
    on_exit(fn -> File.rm_rf!(Path.dirname(@structure_file)) end)
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
  end

  test "it writes the schema the migrations produce, without pg_dump's restrict lines, the same on every run" do
    Dump.run([])
    assert_received {:mix_shell, :info, ["wrote " <> @structure_file]}
    first = File.read!(@structure_file)
    assert first =~ "CREATE TABLE public.mediate_dev_rows"
    assert first =~ "OWNER TO mediate_owner"
    assert first =~ "GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.mediate_dev_rows TO mediate_app"
    refute first =~ "\\restrict"
    refute first =~ "\\unrestrict"
    refute Process.whereis(TestRepos.Dump)

    Dump.run([])
    assert File.read!(@structure_file) == first
  end

  test "it takes no arguments and the mechanism validates its options" do
    assert_raise Mix.Error, ~r/takes no arguments/, fn -> Dump.run(["--x"]) end
    assert_raise NimbleOptions.ValidationError, fn -> Structure.dump(repo: TestRepos.Dump) end
  end
end
