defmodule Mediate.OpenFGA.VersionTest do
  use ExUnit.Case, async: true

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.OpenFGA
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Client.Fake
  alias Mediate.OpenFGA.Conformance.Reference
  alias Mediate.OpenFGA.Model
  alias Mediate.OpenFGA.Version
  alias Mediate.PolicyRelease
  alias Mediate.Test
  alias Mediate.TestRepos.Sandboxed

  @at ~U[2026-09-09 12:00:00Z]

  # A fake on an agent of the test's own is the server here. What a release
  # does to a server is one call, and the id it answers with is the policy
  # version.
  setup do
    agent = start_supervised!(Fake)
    {:ok, store_id} = Fake.create_store(agent, "version")

    :ok = Test.with_config(engine: {OpenFGA, address: agent, store_id: store_id, client: Fake}, clock: fn -> @at end)

    :ok =
      Binding.override(
        repo: Sandboxed,
        model_file: Reference.model(),
        mapping: Reference,
        author: "mediate_openfga",
        approval: "the conformance suite"
      )

    {:ok, agent: agent, store_id: store_id}
  end

  test "the text is what the model file holds, and a file that is not there is an invalid binding" do
    {:ok, binding} = Binding.resolve()

    assert {:ok, text} = Version.text(binding)
    assert text =~ "type folder"

    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> rest}} =
             Version.text(%{binding | model_file: "priv/conformance/absent.fga"})

    assert rest =~ "the model file priv/conformance/absent.fga could not be read"
  end

  test "the policy version is the model id, and the text is what the model file holds" do
    {:ok, binding} = Binding.resolve()
    text = File.read!(Reference.model())

    assert %PolicyRelease{} = release = Version.release(OpenFGA, "model-1", text, binding, config())
    assert release.engine == OpenFGA
    assert release.policy_version == "model-1"
    assert release.author == "mediate_openfga"
    assert release.approval == "the conformance suite"
    assert release.released_at == @at
    assert release.text == text
    assert release.text =~ "type folder"
    assert release.text_location == nil
    assert release.text_hash == Version.text_hash(text)
    assert String.length(release.text_hash) == 64
  end

  test "over the text cap the release names the file the model is in instead of carrying the text" do
    {:ok, binding} = Binding.resolve()
    text = File.read!(Reference.model())

    assert %PolicyRelease{} = release = Version.release(OpenFGA, "model-1", text, binding, config(8))
    assert release.text == nil
    assert release.text_location == "the model file priv/conformance/model.fga"
    assert release.text_hash == Version.text_hash(text)
  end

  test "release writes the model and publishes the release with the id the server gave it", context do
    :telemetry.attach(inspect(self()), PolicyRelease.event(), &__MODULE__.forward/4, self())

    assert {:ok, %PolicyRelease{} = release} = OpenFGA.release()
    assert release.engine == OpenFGA
    assert release.policy_version == "model-1"
    assert release.text_hash == Version.text_hash(File.read!(Reference.model()))
    assert models(context.agent) == [Model.read!(Reference.model())]

    assert_receive {:policy_release, %{release: ^release}}
    refute_receive {:policy_release, _later}
  after
    :telemetry.detach(inspect(self()))
  end

  test "a model is immutable, so a second release is a model and a policy version of its own", context do
    assert {:ok, %PolicyRelease{policy_version: "model-1"}} = OpenFGA.release()
    :ok = Binding.override(model_file: changed())

    assert {:ok, %PolicyRelease{policy_version: "model-2"}} = OpenFGA.release()
    assert length(models(context.agent)) == 2
  end

  test "a model file that is not there releases nothing" do
    :ok = Binding.override(model_file: "priv/conformance/absent.fga")

    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> _rest} = error} = OpenFGA.release()
    assert error.message =~ "priv/conformance/absent.fga could not be read"
  end

  test "a configuration naming another engine releases nothing under this one", context do
    :ok = Test.with_config(engine: Mediate.Test.Fake)

    assert {:error, %Error{reason: :invalid, message: "invalid store: " <> message}} = OpenFGA.release()
    assert message == "#{inspect(Mediate.Test.Fake)} is the configured engine, not this one"
    assert models(context.agent) == []
  end

  @doc false
  @spec forward([atom()], map(), map(), pid()) :: :ok
  def forward(_event, _measurements, metadata, pid) do
    send(pid, {:policy_release, metadata})
    :ok
  end

  defp config(policy_text_bytes \\ 65_536) do
    Config.new!(
      engine: {OpenFGA, address: "127.0.0.1:1", store_id: "store"},
      clock: fn -> @at end,
      caps: [policy_text_bytes: policy_text_bytes]
    )
  end

  defp models(agent) do
    for {:write_authorization_model, model} <- Fake.calls(agent), do: model
  end

  # A model that differs from the bound one by a relation, in a file of this
  # test's own. So a second release has a text of its own to carry.
  defp changed do
    path = Path.join([File.cwd!(), "tmp", "model-#{System.unique_integer([:positive])}.fga"])
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      String.replace(File.read!(Reference.model()), "define can_edit: editor", "define can_edit: editor or reader")
    )

    on_exit(fn -> File.rm_rf!(path) end)

    path
  end
end
