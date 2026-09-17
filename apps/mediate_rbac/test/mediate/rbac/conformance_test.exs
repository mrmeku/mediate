defmodule Mediate.Rbac.ConformanceTest do
  use Mediate.Conformance.AdapterCase,
    async: false,
    adapter: Mediate.Rbac,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Fixture.World,
    sandbox: Mediate.Dev.Sandbox,
    committed: [
      repo: Mediate.TestRepos.Committed,
      owner: Mediate.TestRepos.Owner,
      tables: ~w(mediate_fixture_memberships mediate_fixture_items mediate_fixture_folders mediate_fixture_accounts)
    ],
    versions: Mediate.Rbac.Conformance.Versions

  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Roles

  setup %{repo: repo} do
    :ok = Binding.override(policy: Roles, repo: repo)
  end
end
