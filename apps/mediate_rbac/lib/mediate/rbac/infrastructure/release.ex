defmodule Mediate.Rbac.Infrastructure.Release do
  @moduledoc false
  # `Mediate.Rbac.release/0`: the bound policy's release, built by
  # `Mediate.Rbac.Version.release/4` at the configured clock and published
  # by `Mediate.PolicyRelease.publish/1`.

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.PolicyRelease
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Version

  @doc "Builds the bound policy's release, publishes it once per call, and answers it."
  @spec publish(module()) :: {:ok, PolicyRelease.t()} | {:error, Error.t()}
  def publish(engine) when is_atom(engine) do
    with {:ok, %Binding{policy: policy}} <- Binding.resolve(),
         {:ok, %Config{} = config} <- Config.resolve() do
      release = Version.release(engine, policy, config, config.clock.())
      :ok = PolicyRelease.publish(release)

      {:ok, release}
    end
  end
end
