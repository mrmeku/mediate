defmodule ExampleRbac.Infrastructure.PolicyTest do
  use ExUnit.Case, async: true

  alias ExampleRbac.Infrastructure.Policy
  alias Mediate.Config
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Facts

  test "every fact a rule reads is declared on its schema" do
    assert Facts.check(Policy) == :ok
  end

  test "the boot names the engine, the policy module and the repo" do
    assert {:ok, %Config{} = config} = Config.resolve()
    assert Config.engine(config) == {Mediate.Rbac, []}
    assert {:ok, %Binding{policy: Policy, repo: Example.Infrastructure.Repo}} = Binding.resolve()
  end

  test "the policy release carries the version the policy module declares" do
    assert Mediate.Rbac.Version.policy_version(Policy) == "2026.09.1"
  end

  test "the role table grants each role the actions docs/example.md gives it" do
    assert Mediate.Rbac.Policy.roles_for(Policy, :read) == [:contributor, :maintainer, :admin, :reviewer]
    assert Mediate.Rbac.Policy.roles_for(Policy, :change_visibility) == [:admin]
    assert Mediate.Rbac.Policy.roles_for(Policy, :approve_visibility) == [:reviewer]
  end
end
