defmodule Mediate.Cerbos.Infrastructure.Release do
  @moduledoc false
  # `Mediate.Cerbos.release/0`: the bound directory's release, built by
  # `Mediate.Cerbos.Version.release/4` at the configured clock and published
  # by `Mediate.PolicyRelease.publish/1`.

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Version
  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.PolicyRelease

  @doc "Builds the bound directory's release, publishes it once per call, and answers it."
  @spec publish(module()) :: {:ok, PolicyRelease.t()} | {:error, Error.t()}
  def publish(engine) when is_atom(engine) do
    with {:ok, %Binding{} = binding} <- Binding.resolve(),
         {:ok, %Config{} = config} <- Config.resolve(),
         {:ok, %PolicyRelease{} = release} <- Version.release(engine, binding, config, config.clock.()) do
      :ok = PolicyRelease.publish(release)

      {:ok, release}
    end
  end
end
