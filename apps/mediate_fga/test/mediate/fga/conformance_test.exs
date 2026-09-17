defmodule Mediate.Fga.ConformanceTest do
  use Mediate.Conformance.AdapterCase,
    adapter: Mediate.Fga,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Fixture.World,
    sandbox: Mediate.Dev.Sandbox,
    async: false,
    setup_queries: 0,
    seed: Mediate.Fga.Seed,
    outage: Mediate.Fga.ConformanceTest.Unreachable,
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
    versions: Mediate.Fga.Conformance.Versions

  alias Mediate.Dev
  alias Mediate.Fga
  alias Mediate.Fga.Binding
  alias Mediate.Fga.Client.Http
  alias Mediate.Fga.Conformance.Mapping
  alias Mediate.PolicyVersion
  alias Mediate.Test

  @model "priv/conformance/model.fga"

  defmodule Unreachable do
    @moduledoc "The outage: the server is out of reach for the rest of the test."

    alias Mediate.Config

    @doc "Points the configuration at a port nothing listens on, and keeps the store and the model it pins."
    @spec outage() :: :ok
    def outage do
      {:ok, config} = Config.resolve()
      {Fga, options} = Config.adapter(config)

      Test.with_config(adapter: {Fga, Keyword.put(options, :endpoint, "127.0.0.1:1")})
    end
  end

  # A store per test on the run's server, and the model published into it
  # as a policy version. So the id every question pins is the id the
  # publication answered with. The template hands each test the repo of its
  # tier, so the test makes the binding per test as well. The markers and
  # the tables the drain reads are that tier's.
  setup %{repo: repo} do
    server = Dev.Fga.info()
    {:ok, store} = Http.create_store(server.address, name())
    :ok = Test.with_config(adapter: {Fga, endpoint: server.address, store_id: store})
    :ok = Binding.override(repo: repo, model: @model, mapping: Mapping, author: "conformance", approval: "conformance")
    assert {:ok, %PolicyVersion{version: model}} = Fga.publish()
    Test.with_config(adapter: {Fga, endpoint: server.address, store_id: store, model_id: model})
  end

  defp name, do: "conformance-#{System.unique_integer([:positive])}"
end
