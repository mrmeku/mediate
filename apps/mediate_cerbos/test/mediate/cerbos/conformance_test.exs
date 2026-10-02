defmodule Mediate.Cerbos.ConformanceTest do
  use Mediate.Conformance.EngineCase,
    async: false,
    engine: Mediate.Cerbos,
    repo: Mediate.TestRepos.Sandboxed,
    world: Mediate.Conformance.Reference.World,
    setup: Mediate.Dev.Sandbox,
    queries_per_call: 1,
    outage: Mediate.Cerbos.Conformance.Outage,
    policy: Mediate.Cerbos.Conformance.Policy,
    durable: [
      repo: Mediate.TestRepos.Durable,
      owner: Mediate.TestRepos.Owner,
      tables: ~w(mediate_fixture_memberships mediate_fixture_items mediate_fixture_folders mediate_fixture_accounts)
    ]

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Reference
  alias Mediate.Dev
  alias Mediate.Test

  # The case hands each test the repo of its tier, so the binding is per
  # test. Both tiers ask the run's server, which answers from the policy
  # files in the repository. Each reads its attribute values through its
  # own connection.
  setup %{repo: repo} do
    server = Dev.Cerbos.current!()
    :ok = Test.with_config(engine: {Mediate.Cerbos, address: server.http})

    Binding.override(
      repo: repo,
      declarations: Reference,
      policy_dir: server.policy_dir,
      commit: "conformance",
      author: "mediate_cerbos",
      approval: "the conformance suite"
    )
  end
end
