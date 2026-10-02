defmodule Mediate.Rbac.VersionTest do
  use ExUnit.Case, async: true

  alias Mediate.Config
  alias Mediate.PolicyRelease
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Predicates
  alias Mediate.Rbac.Conformance.Reference
  alias Mediate.Rbac.Policy
  alias Mediate.Rbac.Version
  alias Mediate.TestRepos.Sandboxed

  setup do
    :ok = Mediate.Test.with_config(engine: Mediate.Rbac)
    :ok = Binding.override(policy: Reference, repo: Sandboxed)
  end

  test "the release carries the version, the hash of the text, and the text with the modules and the role table" do
    {:ok, config} = Config.resolve()
    released_at = DateTime.utc_now()
    release = Version.release(Mediate.Rbac, Reference, config, released_at)

    assert %PolicyRelease{engine: Mediate.Rbac, policy_version: "conformance", author: "mediate_rbac"} = release
    assert release.approval == "the conformance suite"
    assert release.released_at == released_at
    assert release.text_hash == Version.text_hash(Reference)
    assert String.length(release.text_hash) == 64
    assert release.text == Version.text(Reference)
    assert release.text =~ "modules:\n  #{inspect(Predicates)}: "
    assert release.text =~ "\n  #{inspect(Reference)}: "
    assert release.text =~ "roles:\n  reader: read\n  editor: read, edit\n"
    assert release.text_location == nil
  end

  test "the text names each module with the digest of its bytecode, so a changed rule is a new hash" do
    digest = Base.encode16(Reference.module_info(:md5), case: :lower)
    assert Version.text(Reference) =~ "  #{inspect(Reference)}: #{digest}\n"
    assert Version.text_hash(Reference) == Base.encode16(:crypto.hash(:sha256, Version.text(Reference)), case: :lower)
  end

  test "over the text cap the release carries the location of the modules" do
    :ok = Mediate.Test.with_config(caps: [policy_text_bytes: 8])
    {:ok, config} = Config.resolve()
    release = Version.release(Mediate.Rbac, Reference, config, DateTime.utc_now())
    assert release.text == nil
    assert release.text_location == "modules #{inspect(Predicates)}, #{inspect(Reference)}"
  end

  test "release publishes the bound policy's release, once per call" do
    :telemetry.attach(inspect(self()), PolicyRelease.event(), &__MODULE__.forward/4, self())

    assert {:ok, %PolicyRelease{} = release} = Mediate.Rbac.release()
    assert release.engine == Mediate.Rbac
    assert release.policy_version == "conformance"
    assert release.text =~ "  reader: read\n"

    assert_receive {:policy_release, %{release: ^release}}
    refute_receive {:policy_release, _later}
  after
    :telemetry.detach(inspect(self()))
  end

  test "a policy that names another version releases under that one" do
    assert {:ok, %PolicyRelease{policy_version: "conformance"}} = Mediate.Rbac.release()
    :ok = Binding.override(policy: Mediate.Rbac.VersionTest.Later)

    assert {:ok, %PolicyRelease{policy_version: "later"}} = Mediate.Rbac.release()
  end

  test "the default version is the text hash" do
    :ok = Binding.override(policy: Mediate.Rbac.VersionTest.Unversioned)

    assert Version.policy_version(Mediate.Rbac.VersionTest.Unversioned) ==
             Version.text_hash(Mediate.Rbac.VersionTest.Unversioned)
  end

  @doc false
  @spec forward([atom()], map(), map(), pid()) :: :ok
  def forward(_event, _measurements, metadata, pid) do
    send(pid, {:policy_release, metadata})
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
