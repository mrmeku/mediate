defmodule Mediate.OpenFGA.Conformance.Policy do
  @moduledoc """
  The change-management artifact of this engine
  (`Mediate.Conformance.Policy`). `tighten/0`:

  - writes the conformance model with `can_read` narrowed to a reader alone
    to a file of its own
  - binds that file
  - releases it to the test's store
  - pins the configuration to the model id the server answered with

  `restore/0` binds the boot model again and pins the boot id. The server
  keeps every model. So the server answers a question pinned to an id
  under that model at once, and neither call waits.
  """

  @behaviour Mediate.Conformance.Policy

  alias Mediate.Config
  alias Mediate.Conformance.Policy
  alias Mediate.OpenFGA
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Conformance.Reference
  alias Mediate.PolicyRelease
  alias Mediate.Test

  @clause "define can_read: reader or editor"
  @tightened "define can_read: reader"
  @boot {__MODULE__, :boot}

  @impl Policy
  def tighten do
    {OpenFGA, options} = engine()
    path = Path.join(System.tmp_dir!(), "mediate-openfga-tightened-#{System.unique_integer([:positive])}.fga")
    File.write!(path, tightened!())
    Process.put(@boot, {Keyword.fetch!(options, :model_id), path})
    :ok = Binding.override(model_file: path)

    with {:ok, %PolicyRelease{} = release} <- OpenFGA.release() do
      :ok = pin(options, release.policy_version)
      {:ok, release}
    end
  end

  @impl Policy
  def restore do
    {OpenFGA, options} = engine()
    {boot, path} = Process.delete(@boot)
    File.rm!(path)
    :ok = Binding.override(model_file: Reference.model())
    pin(options, boot)
  end

  defp tightened! do
    text = File.read!(Reference.model())

    if String.contains?(text, @clause) do
      String.replace(text, @clause, @tightened)
    else
      raise ArgumentError, "#{Reference.model()} no longer holds `#{@clause}`, which the tightening narrows"
    end
  end

  defp engine do
    {:ok, %Config{} = config} = Config.resolve()
    Config.engine(config)
  end

  defp pin(options, model_id), do: Test.with_config(engine: {OpenFGA, Keyword.put(options, :model_id, model_id)})
end
