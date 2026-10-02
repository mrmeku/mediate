defmodule Mediate.Postgres.ConformanceTest do
  use Mediate.Conformance.EngineCase,
    async: false,
    engine: Mediate.Postgres,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Reference.World,
    setup: Mediate.Dev.Sandbox,
    queries_per_call: 2,
    outage: Mediate.Postgres.ConformanceTest.Unreachable,
    policy: Mediate.Postgres.Conformance.Policy,
    durable: [
      repo: Mediate.TestRepos.Durable,
      owner: Mediate.TestRepos.Owner,
      tables: ~w(mediate_fixture_memberships mediate_fixture_items mediate_fixture_folders mediate_fixture_accounts)
    ]

  alias Mediate.Conformance.Outage
  alias Mediate.Postgres.Binding

  defmodule Stopped do
    @moduledoc "A repo with no configuration and no start, so every statement through it raises."

    use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres
    use Mediate.Repo
  end

  defmodule Unreachable do
    @moduledoc "The outage: the database is out of reach for the rest of the test."

    @behaviour Outage

    @impl Outage
    def disconnect, do: Binding.override(repo: Stopped)
  end

  # The case hands each test the repo of its tier, so the test makes the
  # binding, not the boot. The sandboxed tier and the durable tier read
  # the same rules through different connections.
  setup %{repo: repo} do
    :ok =
      Binding.override(
        repo: repo,
        schemas: [Mediate.Fixture.Account, Mediate.Fixture.Folder, Mediate.Fixture.Item, Mediate.Fixture.Membership]
      )
  end
end
