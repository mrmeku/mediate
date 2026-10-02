defmodule Mediate.OpenFGA.ConformanceTest do
  use Mediate.Conformance.EngineCase,
    async: false,
    engine: Mediate.OpenFGA,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Reference.World,
    setup: Mediate.Dev.Sandbox,
    queries_per_call: 0,
    mirror: Mediate.OpenFGA.Conformance.Mirror,
    outage: Mediate.OpenFGA.Conformance.Outage,
    policy: Mediate.OpenFGA.Conformance.Policy,
    durable: [
      repo: Mediate.TestRepos.Durable,
      owner: Mediate.TestRepos.Owner,
      tables: ~w(mediate_fixture_memberships mediate_fixture_items mediate_fixture_folders mediate_fixture_accounts)
    ]

  alias Mediate.Dev
  alias Mediate.OpenFGA
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Client.HTTP
  alias Mediate.OpenFGA.Conformance.Reference
  alias Mediate.PolicyRelease
  alias Mediate.Test

  # A store per test on the run's server, and the model released into it.
  # So the id every question pins is the id the release answered with. The
  # case hands each test the repo of its tier, so the test makes the binding
  # per test as well. The markers and the tables the sync reads are that
  # tier's.
  setup %{repo: repo} do
    server = Dev.OpenFGA.current!()
    {:ok, store_id} = HTTP.create_store(server.http, name())
    :ok = Test.with_config(engine: {OpenFGA, address: server.http, store_id: store_id})

    :ok =
      Binding.override(
        repo: repo,
        model_file: Reference.model(),
        mapping: Reference,
        author: "mediate_openfga",
        approval: "the conformance suite"
      )

    assert {:ok, %PolicyRelease{policy_version: model_id}} = OpenFGA.release()
    Test.with_config(engine: {OpenFGA, address: server.http, store_id: store_id, model_id: model_id})
  end

  defp name, do: "conformance-#{System.unique_integer([:positive])}"
end
