defmodule Mediate.Fga.Infrastructure.Version do
  # The publish of the bound model. `publish/1` reads the model text the
  # binding names, compiles it, writes it to the server, and emits the
  # version the server gave it as telemetry. It stores nothing, so the
  # event is the whole of what a publication leaves behind. Every call
  # writes a model. A model is immutable and the server keeps every one, so
  # nothing here can tell a text the server holds already from a new one.
  # What a version is, and what it holds, is `Mediate.Fga.Version`'s.
  @moduledoc false

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.Fga.Binding
  alias Mediate.Fga.Infrastructure.Store
  alias Mediate.Fga.Version
  alias Mediate.PolicyVersion

  @doc "Writes the bound model to the server and emits the version the server names it by."
  @spec publish(module()) :: {:ok, PolicyVersion.t()} | {:error, Error.t()}
  def publish(adapter) when is_atom(adapter) do
    with {:ok, %Binding{} = binding} <- Binding.resolve(),
         {:ok, %Config{} = config} <- Config.resolve(),
         {:ok, text} <- Binding.text(binding),
         {:ok, id} <- written(adapter, binding) do
      {:ok, emitted(version(adapter, binding, config, {id, text}))}
    end
  end

  defp written(adapter, %Binding{} = binding) do
    with {:ok, %Store{} = store} <- Store.resolve(adapter),
         {:ok, model} <- Binding.compiled(binding) do
      store.client.write_model(store.endpoint, store.store, model)
    end
  end

  defp version(adapter, %Binding{} = binding, %Config{} = config, {id, text}) do
    Version.of(adapter, id, text,
      author: binding.author,
      approval: binding.approval,
      at: config.clock.(),
      path: binding.model,
      content_bytes: config.caps[:policy_content_bytes]
    )
  end

  defp emitted(%PolicyVersion{} = version) do
    :telemetry.execute(Version.telemetry_event(), %{}, %{version: version})

    version
  end
end
