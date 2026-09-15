defmodule Mediate.Cerbos.VersionTest do
  use ExUnit.Case, async: true

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Attributes
  alias Mediate.Cerbos.Sidecar
  alias Mediate.Cerbos.Version
  alias Mediate.Config
  alias Mediate.PolicyVersion
  alias Mediate.Test
  alias Mediate.TestRepos.Sandboxed

  # Each test gets its own sidecar over a copy of the conformance policies,
  # because a test here writes into the directory it reads.
  setup do
    sidecar = Sidecar.own!()
    :ok = Test.with_config(adapter: {Mediate.Cerbos, address: sidecar.address})

    :ok =
      Binding.override(
        repo: Sandboxed,
        attributes: Attributes,
        policies: sidecar.policies,
        commit: "conformance",
        author: "mediate_cerbos",
        approval: "the conformance suite"
      )

    {:ok, sidecar: sidecar}
  end

  test "the version is the commit, and the content is the policy files each preceded by its path" do
    {:ok, config} = Config.resolve()
    {:ok, binding} = Binding.resolve()
    at = DateTime.utc_now()

    assert {:ok, %PolicyVersion{} = version} = Version.of(Mediate.Cerbos, binding, config, at)
    assert version.adapter == Mediate.Cerbos
    assert version.version == "conformance"
    assert version.author == "mediate_cerbos"
    assert version.approval == "the conformance suite"
    assert version.at == at
    assert version.content =~ "# mediate-policy: folder.yaml"
    assert version.content =~ "# mediate-policy: item.yaml"
    assert version.content =~ "resource: folder"
    assert version.pointer == nil
    assert version.content_hash == Version.content_hash(version.content)
    assert String.length(version.content_hash) == 64
  end

  test "over the content cap the version carries a pointer to the directory and the commit", ctx do
    :ok = Test.with_config(caps: [policy_content_bytes: 8])
    {:ok, config} = Config.resolve()
    {:ok, binding} = Binding.resolve()

    assert {:ok, %PolicyVersion{} = version} = Version.of(Mediate.Cerbos, binding, config, DateTime.utc_now())
    assert version.content == nil
    assert version.pointer == "policies in #{ctx.sidecar.policies} at conformance"
    assert String.length(version.content_hash) == 64
  end

  test "the text carries the files back, by path, in the order it holds them" do
    {:ok, binding} = Binding.resolve()

    assert {:ok, files} = Version.files(binding)
    assert Enum.map(files, &elem(&1, 0)) == ["folder.yaml", "item.yaml"]
    assert Version.from_text(Version.to_text(files)) == files
  end

  test "a text with a trailing marker and no body carries no file back" do
    assert Version.from_text("# mediate-policy: folder.yaml") == []
  end

  test "a directory that changed without a commit is a hash that no longer matches", ctx do
    {:ok, binding} = Binding.resolve()
    assert {:ok, before} = Version.content(binding)

    File.write!(Path.join(ctx.sidecar.policies, "folder.yaml"), "# nothing the sidecar reads as a policy\n")

    assert {:ok, changed} = Version.content(binding)
    assert Version.ref(binding) == "conformance"
    refute Version.content_hash(changed) == Version.content_hash(before)
  end

  test "a policy directory that holds nothing is a version with an empty content" do
    :ok = Binding.override(policies: Path.join(File.cwd!(), "tmp/no-policies-here"))
    {:ok, binding} = Binding.resolve()

    assert Version.content(binding) == {:ok, ""}
  end

  test "publish emits one policy version event carrying the commit" do
    :telemetry.attach(inspect(self()), Version.telemetry_event(), &__MODULE__.forward/4, self())

    assert {:ok, %PolicyVersion{} = version} = Mediate.Cerbos.publish()
    assert version.adapter == Mediate.Cerbos
    assert version.version == "conformance"

    assert_receive {:policy_version, %{version: ^version}}
    refute_receive {:policy_version, _later}
  after
    :telemetry.detach(inspect(self()))
  end

  test "a later commit publishes under that commit" do
    assert {:ok, %PolicyVersion{version: "conformance"}} = Mediate.Cerbos.publish()
    :ok = Binding.override(commit: "later")

    assert {:ok, %PolicyVersion{version: "later"}} = Mediate.Cerbos.publish()
  end

  @doc false
  @spec forward([atom()], map(), map(), pid()) :: :ok
  def forward(_event, _measurements, metadata, pid) do
    send(pid, {:policy_version, metadata})
    :ok
  end
end
