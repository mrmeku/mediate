defmodule Mediate.Fga.Conformance.Versions do
  @moduledoc """
  The change-management artifact of the OpenFGA adapter. `docs/conformance.md`
  §4 says what a `Versions` module owes the suite. `tighten/0`:

  - writes the conformance model with `can_read` narrowed to a reader alone
    to a file of its own
  - binds that file
  - publishes it to the test's store
  - pins the configuration to the model id the server answered with

  `restore/0` binds the boot model again and pins the boot id. The server
  keeps every model. So the server answers a question pinned to an id under
  that model at once, and neither call waits.
  """

  @behaviour Mediate.Conformance.Versions

  alias Mediate.Config
  alias Mediate.Conformance.Versions
  alias Mediate.Fga
  alias Mediate.Fga.Binding
  alias Mediate.Fga.Version
  alias Mediate.PolicyVersion
  alias Mediate.Test

  @model "priv/conformance/model.fga"
  @clause "define can_read: reader or editor"
  @tightened "define can_read: reader"
  @boot {__MODULE__, :boot}

  @impl Versions
  def event, do: Version.telemetry_event()

  @impl Versions
  def tighten do
    {Fga, options} = adapter()
    path = Path.join(System.tmp_dir!(), "mediate-fga-tightened-#{System.unique_integer([:positive])}.fga")
    File.write!(path, tightened!())
    Process.put(@boot, {Keyword.fetch!(options, :model_id), path})
    :ok = Binding.override(model: path)

    with {:ok, %PolicyVersion{} = version} <- Fga.publish() do
      :ok = pin(options, version.version)
      {:ok, version}
    end
  end

  @impl Versions
  def restore do
    {Fga, options} = adapter()
    {boot, path} = Process.delete(@boot)
    File.rm!(path)
    :ok = Binding.override(model: @model)
    pin(options, boot)
  end

  defp tightened! do
    text = File.read!(@model)

    if String.contains?(text, @clause) do
      String.replace(text, @clause, @tightened)
    else
      raise ArgumentError, "#{@model} no longer holds `#{@clause}`, which the tightening narrows"
    end
  end

  defp adapter do
    {:ok, %Config{} = config} = Config.resolve()
    Config.adapter(config)
  end

  defp pin(options, model_id), do: Test.with_config(adapter: {Fga, Keyword.put(options, :model_id, model_id)})
end
