defmodule Mediate.Conformance.EngineCaseTest do
  use Mediate.Conformance.EngineCase,
    async: false,
    engine: Mediate.Test.Fake,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Reference.World,
    setup: Mediate.Dev.Sandbox,
    mirror: Mediate.Conformance.Reference.Mirror,
    outage: Mediate.Conformance.Reference.Outage,
    policy: Mediate.Conformance.Reference.Policy,
    durable: [
      repo: Mediate.TestRepos.Durable,
      owner: Mediate.TestRepos.Owner,
      tables: ~w(mediate_fixture_memberships mediate_fixture_items mediate_fixture_folders mediate_fixture_accounts)
    ]

  alias Mediate.Config
  alias Mediate.Test.Fake

  setup do
    rules = start_supervised!(%{id: Fake, start: {Fake, :start_link, []}})
    :ok = Mediate.Test.with_config(engine: {Fake, rules: rules})
    {:ok, rules: rules}
  end

  test "the setup binds the engine and the clock", %{rules: rules} do
    assert {:ok, %Config{} = config} = Config.resolve()
    assert {Fake, options} = config.engine
    assert options[:rules] == rules
    assert %DateTime{} = config.clock.()
  end
end

defmodule Mediate.Conformance.EngineCaseSyncingTest do
  use Mediate.Conformance.EngineCase,
    async: false,
    engine: Mediate.Test.SyncingEngine,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Reference.World,
    setup: Mediate.Dev.Sandbox,
    mirror: Mediate.Conformance.Reference.Mirror

  alias Mediate.Test.Fake
  alias Mediate.Test.SyncingEngine

  setup do
    rules = start_supervised!(%{id: Fake, start: {Fake, :start_link, []}})
    :ok = Mediate.Test.with_config(engine: {SyncingEngine, rules: rules})
    :ok
  end

  test "the engine this module runs has state of its own to sync" do
    assert Code.ensure_loaded?(SyncingEngine) and function_exported?(SyncingEngine, :sync, 0)
  end
end
