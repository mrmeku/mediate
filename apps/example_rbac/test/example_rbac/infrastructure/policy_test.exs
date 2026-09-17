defmodule ExampleRbac.Infrastructure.PolicyTest do
  use ExUnit.Case, async: true

  alias ExampleRbac.Infrastructure.Policy
  alias Mediate.Config
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Coverage

  test "every fact a rule reads is declared on the schema it reads" do
    assert Coverage.check(Policy) == :ok
  end

  test "the boot names the adapter, the policy, and the repo" do
    assert {:ok, %Config{} = config} = Config.resolve()
    assert Config.adapter(config) == {Mediate.Rbac, []}
    assert {:ok, %Binding{policy: Policy, repo: Example.Infrastructure.Repo}} = Binding.resolve()
    assert Mediate.Rbac.Version.ref(Policy) == "2026.09.1"
  end

  test "the role table holds the permissions docs/example.md gives each role" do
    assert Mediate.Rbac.Policy.roles_for(Policy, :read) == [:contributor, :maintainer, :admin, :reviewer]
    assert Mediate.Rbac.Policy.roles_for(Policy, :change_visibility) == [:admin]
    assert Mediate.Rbac.Policy.roles_for(Policy, :approve_visibility) == [:reviewer]
  end
end
