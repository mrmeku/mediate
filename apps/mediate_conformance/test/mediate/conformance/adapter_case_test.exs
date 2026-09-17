defmodule Mediate.Conformance.AdapterCaseTest do
  use Mediate.Conformance.AdapterCase,
    async: false,
    adapter: Mediate.Test.Fake,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Fixture.World,
    sandbox: Mediate.Dev.Sandbox,
    seed: Mediate.Conformance.Fixture.Seed,
    outage: Mediate.Conformance.Fixture.Seed,
    committed: [
      repo: Mediate.TestRepos.Committed,
      owner: Mediate.TestRepos.Owner,
      tables: ~w(mediate_fixture_memberships mediate_fixture_items mediate_fixture_folders mediate_fixture_accounts)
    ]

  alias Mediate.Config
  alias Mediate.Test.Fake

  setup do
    rules = start_supervised!(%{id: Fake, start: {Fake, :start_link, []}})
    :ok = Mediate.Test.with_config(adapter: {Fake, rules: rules})
    {:ok, rules: rules}
  end

  test "the setup binds the adapter and the clock", %{rules: rules} do
    assert {:ok, %Config{} = config} = Config.resolve()
    assert {Fake, options} = config.adapter
    assert options[:rules] == rules
    assert %DateTime{} = config.clock.()
  end
end

defmodule Mediate.Conformance.AdapterCaseSettlingTest do
  use Mediate.Conformance.AdapterCase,
    async: false,
    adapter: Mediate.Test.SettlingAdapter,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Fixture.World,
    sandbox: Mediate.Dev.Sandbox,
    seed: Mediate.Conformance.Fixture.Seed

  alias Mediate.Test.Fake
  alias Mediate.Test.SettlingAdapter

  setup do
    rules = start_supervised!(%{id: Fake, start: {Fake, :start_link, []}})
    :ok = Mediate.Test.with_config(adapter: {SettlingAdapter, rules: rules})
    :ok
  end

  test "the adapter this module runs has state of its own to settle" do
    assert Code.ensure_loaded?(SettlingAdapter) and function_exported?(SettlingAdapter, :settle, 0)
  end
end
