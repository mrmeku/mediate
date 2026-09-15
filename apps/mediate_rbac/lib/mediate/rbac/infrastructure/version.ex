defmodule Mediate.Rbac.Infrastructure.Version do
  @moduledoc false

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.PolicyVersion
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Version

  @doc "Emits the bound policy's version once per call, and answers the version."
  @spec publish(module()) :: {:ok, PolicyVersion.t()} | {:error, Error.t()}
  def publish(adapter) when is_atom(adapter) do
    with {:ok, %Binding{policy: policy}} <- Binding.resolve(),
         {:ok, %Config{} = config} <- Config.resolve() do
      version = Version.of(adapter, policy, config, config.clock.())
      :telemetry.execute(Version.telemetry_event(), %{}, %{version: version})

      {:ok, version}
    end
  end
end
