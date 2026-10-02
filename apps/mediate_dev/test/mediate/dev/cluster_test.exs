defmodule Mediate.Dev.ClusterTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL
  alias Mediate.Dev.Cluster
  alias Mediate.Dev.Sandbox
  alias Mediate.Dev.TestRepos.Durable
  alias Mediate.Dev.TestRepos.Owner
  alias Mediate.Dev.TestRepos.Sandboxed

  setup tags do
    Sandbox.setup(Sandboxed, tags)
  end

  test "the sandboxed repo answers a query as the app role on the sandboxed database" do
    assert %{rows: [["mediate_app", "mediate_sandboxed"]]} =
             SQL.query!(Sandboxed, "SELECT current_user::text, current_database()::text")
  end

  test "the app role cannot bypass row level security" do
    assert %{rows: [[false]]} =
             SQL.query!(Sandboxed, "SELECT rolbypassrls FROM pg_roles WHERE rolname = current_user")
  end

  test "the durable and owner repos share the durable database" do
    assert %{rows: [["mediate_app", "mediate_durable"]]} =
             SQL.query!(Durable, "SELECT current_user::text, current_database()::text")

    assert %{rows: [["mediate_owner", "mediate_durable"]]} =
             SQL.query!(Owner, "SELECT current_user::text, current_database()::text")
  end

  test "the names and the config say which role and database a repo gets" do
    cluster = Cluster.current()
    assert Cluster.database_name(:durable) == "mediate_durable"
    assert Cluster.role_name(:owner) == "mediate_owner"

    assert Cluster.config(cluster, :app, :sandboxed) ==
             [socket_dir: cluster.socket_dir, username: "mediate_app", database: "mediate_sandboxed"]
  end

  test "the cluster lives under tmp in the app directory and listens on no TCP port" do
    cluster = Cluster.current()
    assert String.starts_with?(cluster.dir, Path.join(File.cwd!(), "tmp/pg-"))
    assert File.dir?(cluster.data_dir)
    assert %{rows: [[""]]} = SQL.query!(Owner, "SHOW listen_addresses")
  end
end
