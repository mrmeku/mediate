defmodule Mediate.Rbac.VersionTest do
  use ExUnit.Case, async: true

  alias Mediate.Config
  alias Mediate.PolicyVersion
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Predicates
  alias Mediate.Rbac.Conformance.Roles
  alias Mediate.Rbac.Policy
  alias Mediate.Rbac.Version
  alias Mediate.TestRepos.Sandboxed

  setup do
    :ok = Mediate.Test.with_config(adapter: Mediate.Rbac)
    :ok = Binding.override(policy: Roles, repo: Sandboxed)
  end

  test "the version carries the commit, the hash of the rule modules, and the role table as data" do
    {:ok, config} = Config.resolve()
    at = DateTime.utc_now()
    version = Version.of(Mediate.Rbac, Roles, config, at)

    assert %PolicyVersion{adapter: Mediate.Rbac, version: "conformance", author: "mediate_rbac"} = version
    assert version.approval == "the conformance suite"
    assert version.at == at
    assert version.content_hash == Version.content_hash(Roles)
    assert String.length(version.content_hash) == 64
    assert version.content =~ "modules: #{inspect(Predicates)}, #{inspect(Roles)}"
    assert version.content =~ "  reader: read\n  editor: read, edit\n"
    assert version.pointer == nil
  end

  test "over the content cap the version carries a pointer to the modules" do
    :ok = Mediate.Test.with_config(caps: [policy_content_bytes: 8])
    {:ok, config} = Config.resolve()
    version = Version.of(Mediate.Rbac, Roles, config, DateTime.utc_now())
    assert version.content == nil
    assert version.pointer == "modules #{inspect(Predicates)}, #{inspect(Roles)}"
  end

  test "publish emits the bound policy's version, once per call" do
    :telemetry.attach(inspect(self()), Version.telemetry_event(), &__MODULE__.forward/4, self())

    assert {:ok, %PolicyVersion{} = version} = Mediate.Rbac.publish()
    assert version.adapter == Mediate.Rbac
    assert version.version == "conformance"
    assert version.content =~ "  reader: read\n"

    assert_receive {:policy_version, %{version: ^version}}
    refute_receive {:policy_version, _later}
  after
    :telemetry.detach(inspect(self()))
  end

  test "a policy that names another version publishes under that one" do
    assert {:ok, %PolicyVersion{version: "conformance"}} = Mediate.Rbac.publish()
    :ok = Binding.override(policy: Mediate.Rbac.VersionTest.Later)

    assert {:ok, %PolicyVersion{version: "later"}} = Mediate.Rbac.publish()
  end

  test "the default version is the content hash" do
    :ok = Binding.override(policy: Mediate.Rbac.VersionTest.Unversioned)

    assert Version.ref(Mediate.Rbac.VersionTest.Unversioned) ==
             Version.content_hash(Mediate.Rbac.VersionTest.Unversioned)
  end

  @doc false
  @spec forward([atom()], map(), map(), pid()) :: :ok
  def forward(_event, _measurements, metadata, pid) do
    send(pid, {:policy_version, metadata})
    :ok
  end

  defmodule Later do
    @moduledoc false
    use Policy, version: "later"

    role :reader, [:read]
  end

  defmodule Unversioned do
    @moduledoc false
    use Policy

    role :reader, [:read]
  end
end
