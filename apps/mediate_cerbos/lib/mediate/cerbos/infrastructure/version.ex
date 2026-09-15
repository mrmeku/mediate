defmodule Mediate.Cerbos.Infrastructure.Version do
  @moduledoc false

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Version
  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.PolicyVersion

  @doc "Emits the bound directory's commit as a policy version, once per call, and answers the version."
  @spec publish(module()) :: {:ok, PolicyVersion.t()} | {:error, Error.t()}
  def publish(adapter) when is_atom(adapter) do
    with {:ok, %Binding{} = binding} <- Binding.resolve(),
         {:ok, %Config{} = config} <- Config.resolve(),
         {:ok, %PolicyVersion{} = version} <- Version.of(adapter, binding, config, config.clock.()) do
      :telemetry.execute(Version.telemetry_event(), %{}, %{version: version})

      {:ok, version}
    end
  end
end
