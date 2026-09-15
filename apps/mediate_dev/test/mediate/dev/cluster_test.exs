defmodule Mediate.Dev.ClusterTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL
  alias Mediate.Dev.Cluster
  alias Mediate.Dev.Sandbox
  alias Mediate.Dev.TestRepos.Committed
  alias Mediate.Dev.TestRepos.Owner
  alias Mediate.Dev.TestRepos.Sandboxed

  setup tags do
    Sandbox.setup(Sandboxed, tags)
  end

  test "the sandboxed repo answers a query as the application role" do
    assert %{rows: [["mediate_app", "mediate_test"]]} =
             SQL.query!(Sandboxed, "SELECT current_user::text, current_database()::text")
  end

  test "the application role cannot bypass row level security" do
    assert %{rows: [[false]]} =
             SQL.query!(Sandboxed, "SELECT rolbypassrls FROM pg_roles WHERE rolname = current_user")
  end

  test "the committed and owner repos share the committed database" do
    assert %{rows: [["mediate_app", "mediate_committed"]]} =
             SQL.query!(Committed, "SELECT current_user::text, current_database()::text")

    assert %{rows: [["mediate_owner", "mediate_committed"]]} =
             SQL.query!(Owner, "SELECT current_user::text, current_database()::text")
  end

  test "the cluster lives under tmp in the app directory and listens on no TCP port" do
    cluster = Cluster.info()
    assert String.starts_with?(cluster.dir, Path.join(File.cwd!(), "tmp/pg-"))
    assert File.dir?(cluster.data_dir)
    assert %{rows: [[""]]} = SQL.query!(Owner, "SHOW listen_addresses")
  end
end
