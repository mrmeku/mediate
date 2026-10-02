defmodule Mediate.Cerbos.VersionTest do
  use ExUnit.Case, async: true

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Reference
  alias Mediate.Cerbos.Conformance.Server
  alias Mediate.Cerbos.Version
  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.PolicyRelease
  alias Mediate.Test
  alias Mediate.TestRepos.Sandboxed

  # Each test gets its own server over a copy of the conformance policy
  # files, because a test here writes into the directory it reads.
  setup do
    server = Server.start!()
    :ok = Test.with_config(engine: {Mediate.Cerbos, address: server.http})

    :ok =
      Binding.override(
        repo: Sandboxed,
        declarations: Reference,
        policy_dir: server.policy_dir,
        commit: "conformance",
        author: "mediate_cerbos",
        approval: "the conformance suite"
      )

    {:ok, server: server}
  end

  test "the version is the commit, and the text is the policy files each preceded by its path" do
    {:ok, config} = Config.resolve()
    {:ok, binding} = Binding.resolve()
    released_at = DateTime.utc_now()

    assert {:ok, %PolicyRelease{} = release} = Version.release(Mediate.Cerbos, binding, config, released_at)
    assert release.engine == Mediate.Cerbos
    assert release.policy_version == "conformance"
    assert release.author == "mediate_cerbos"
    assert release.approval == "the conformance suite"
    assert release.released_at == released_at
    assert release.text =~ "# mediate-policy: folder.yaml"
    assert release.text =~ "# mediate-policy: item.yaml"
    assert release.text =~ "resource: folder"
    assert release.text_location == nil
    assert release.text_hash == Version.text_hash(release.text)
    assert String.length(release.text_hash) == 64
  end

  test "over the text cap the release carries the location of the directory and the commit", ctx do
    :ok = Test.with_config(caps: [policy_text_bytes: 8])
    {:ok, config} = Config.resolve()
    {:ok, binding} = Binding.resolve()

    assert {:ok, %PolicyRelease{} = release} = Version.release(Mediate.Cerbos, binding, config, DateTime.utc_now())
    assert release.text == nil
    assert release.text_location == "policy files in #{ctx.server.policy_dir} at commit conformance"
    assert String.length(release.text_hash) == 64
  end

  test "the text carries the files back, by path, in the order it holds them" do
    {:ok, binding} = Binding.resolve()

    assert {:ok, files} = Version.files(binding)
    assert Enum.map(files, &elem(&1, 0)) == ["folder.yaml", "item.yaml"]
    assert Version.from_text(Version.text(files)) == files
  end

  test "a text with a trailing marker and no body carries no file back" do
    assert Version.from_text("# mediate-policy: folder.yaml") == []
  end

  test "a directory that changed without a commit is a hash that no longer matches", ctx do
    {:ok, binding} = Binding.resolve()
    {:ok, before} = Version.files(binding)

    File.write!(Path.join(ctx.server.policy_dir, "folder.yaml"), "# nothing the server reads as a policy\n")

    {:ok, changed} = Version.files(binding)
    assert Version.policy_version(binding) == "conformance"
    refute Version.text_hash(Version.text(changed)) == Version.text_hash(Version.text(before))
  end

  test "a policy directory that holds nothing is a release with an empty text" do
    :ok = Binding.override(policy_dir: Path.join(File.cwd!(), "tmp/no-policies-here"))
    {:ok, binding} = Binding.resolve()

    assert Version.files(binding) == {:ok, []}
    assert Version.text([]) == ""
  end

  test "a policy file that cannot be read is an invalid policy directory", ctx do
    path = Path.join(ctx.server.policy_dir, "folder.yaml")
    File.chmod!(path, 0o000)
    on_exit(fn -> File.chmod!(path, 0o644) end)
    {:ok, binding} = Binding.resolve()

    assert {:error, %Error{reason: :invalid, message: message}} = Version.files(binding)
    assert message == "invalid policy_dir: #{path} could not be read: permission denied"
    assert {:error, %Error{reason: :invalid}} = Mediate.Cerbos.release()
  end

  test "release emits one policy release event carrying the commit" do
    :telemetry.attach(inspect(self()), PolicyRelease.event(), &__MODULE__.forward/4, self())

    assert {:ok, %PolicyRelease{} = release} = Mediate.Cerbos.release()
    assert release.engine == Mediate.Cerbos
    assert release.policy_version == "conformance"

    assert_receive {:policy_release, %{release: ^release}}
    refute_receive {:policy_release, _later}
  after
    :telemetry.detach(inspect(self()))
  end

  test "a later commit releases under that commit" do
    assert {:ok, %PolicyRelease{policy_version: "conformance"}} = Mediate.Cerbos.release()
    :ok = Binding.override(commit: "later")

    assert {:ok, %PolicyRelease{policy_version: "later"}} = Mediate.Cerbos.release()
  end

  @doc false
  @spec forward([atom()], map(), map(), pid()) :: :ok
  def forward(_event, _measurements, metadata, pid) do
    send(pid, {:policy_release, metadata})
    :ok
  end
end
