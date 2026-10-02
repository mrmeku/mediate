defmodule Mediate.Rbac.ConformanceTest do
  use Mediate.Conformance.EngineCase,
    async: false,
    engine: Mediate.Rbac,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Reference.World,
    setup: Mediate.Dev.Sandbox,
    policy: Mediate.Rbac.Conformance.Policy,
    durable: [
      repo: Mediate.TestRepos.Durable,
      owner: Mediate.TestRepos.Owner,
      tables: ~w(mediate_fixture_memberships mediate_fixture_items mediate_fixture_folders mediate_fixture_accounts)
    ]

  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Reference

  setup %{repo: repo} do
    :ok = Binding.override(policy: Reference, repo: repo)
  end
end
