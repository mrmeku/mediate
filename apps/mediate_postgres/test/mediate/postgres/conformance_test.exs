defmodule Mediate.Postgres.ConformanceTest do
  use Mediate.Conformance.AdapterCase,
    adapter: Mediate.Postgres,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Fixture.World,
    sandbox: Mediate.Dev.Sandbox,
    async: false,
    setup_queries: 2,
    outage: Mediate.Postgres.ConformanceTest.Unreachable,
    committed: [
      repo: Mediate.TestRepos.Committed,
      owner: Mediate.TestRepos.Owner,
      tables: [
        "mediate_fixture_memberships",
        "mediate_fixture_items",
        "mediate_fixture_folders",
        "mediate_fixture_accounts"
      ]
    ],
    versions: Mediate.Postgres.Conformance.Versions

  alias Mediate.Postgres.Binding

  defmodule Stopped do
    @moduledoc "A repo with no configuration and no start, so every statement through it raises."

    use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres
    use Mediate.Repo
  end

  defmodule Unreachable do
    @moduledoc "The outage: the database is out of reach for the rest of the test."

    @doc "Point the binding at the stopped repo, so the first statement any callback runs raises."
    @spec outage() :: :ok
    def outage, do: Binding.override(repo: Stopped)
  end

  # The template hands each test the repo of its tier, so the test makes
  # the binding, not the boot. The sandboxed tier and the committed tier
  # read the same policies through different connections.
  setup %{repo: repo} do
    :ok =
      Binding.override(
        repo: repo,
        schemas: [
          Mediate.Fixture.Account,
          Mediate.Fixture.Folder,
          Mediate.Fixture.Item,
          Mediate.Fixture.Membership
        ]
      )

    :ok
  end
end
