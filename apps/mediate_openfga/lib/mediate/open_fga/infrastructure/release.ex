defmodule Mediate.OpenFGA.Infrastructure.Release do
  @moduledoc false
  # `Mediate.OpenFGA.release/0`: the bound model's release. `publish/1`
  # reads the model text the binding names, compiles it, writes it to the
  # store, builds the release `Mediate.OpenFGA.Version.release/5` describes
  # at the configured clock, and publishes it by
  # `Mediate.PolicyRelease.publish/1`. It stores nothing, so the event is
  # the whole of what a release leaves behind. Every call writes a model. A
  # model is immutable and the server keeps every one, so nothing here can
  # tell a text the server holds already from a new one.

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Infrastructure.Store
  alias Mediate.OpenFGA.Model
  alias Mediate.OpenFGA.Version
  alias Mediate.PolicyRelease

  @doc "Writes the bound model to the store, publishes its release once per call, and answers it."
  @spec publish(module()) :: {:ok, PolicyRelease.t()} | {:error, Error.t()}
  def publish(engine) when is_atom(engine) do
    with {:ok, %Binding{} = binding} <- Binding.resolve(),
         {:ok, %Config{} = config} <- Config.resolve(),
         {:ok, text} <- Version.text(binding),
         {:ok, model_id} <- written(engine, text) do
      release = Version.release(engine, model_id, text, binding, config)
      :ok = PolicyRelease.publish(release)

      {:ok, release}
    end
  end

  defp written(engine, text) do
    with {:ok, %Store{} = store} <- Store.resolve(engine),
         {:ok, model} <- Model.compile(text) do
      store.client.write_authorization_model(store.address, store.store_id, model)
    end
  end
end
