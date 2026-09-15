defmodule Mediate.Cerbos.ConformanceTest do
  use Mediate.Conformance.AdapterCase,
    adapter: Mediate.Cerbos,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Fixture.World,
    sandbox: Mediate.Dev.Sandbox,
    async: false,
    setup_queries: 1,
    outage: Mediate.Cerbos.ConformanceTest.Unreachable,
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
    versions: Mediate.Cerbos.Conformance.Versions

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Attributes
  alias Mediate.Dev
  alias Mediate.Test

  defmodule Unreachable do
    @moduledoc "The outage: the sidecar is out of reach for the rest of the test."

    @doc "Point the configuration at a port nothing listens on, so every call fails to connect."
    @spec outage() :: :ok
    def outage, do: Test.with_config(adapter: {Mediate.Cerbos, address: "127.0.0.1:1"})
  end

  # The template hands each test the repo of its tier, so the binding is
  # per test. Both tiers ask the run's sidecar, which answers from the
  # policies in the repository. Each reads its facts through its own
  # connection.
  setup %{repo: repo} do
    sidecar = Dev.Cerbos.info()
    :ok = Test.with_config(adapter: {Mediate.Cerbos, address: sidecar.address})

    Binding.override(
      repo: repo,
      attributes: Attributes,
      policies: sidecar.policies,
      commit: "conformance",
      author: "mediate_cerbos",
      approval: "the conformance suite"
    )
  end
end
