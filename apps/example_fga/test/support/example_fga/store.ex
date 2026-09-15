defmodule ExampleFga.Store do
  @moduledoc """
  A store of each test's own, with the boot model in it and pinned for the
  current process.

  The store is per test because it is the engine's copy of the facts. Two
  tests that write tuples into one store read each other's, whatever the
  database does with their rows. `setup/1` creates the store and writes the
  boot model into it, so every question the test asks runs under a model of
  its own.

  Every scenario that writes a fact settles the store before it asks. A
  tuple reaches the store by a pass and not by the write.
  """

  use Boundary, top_level?: true, deps: [ExampleFga, Mediate, Mediate.Fga, Mediate.Test]

  alias Mediate.Dev
  alias Mediate.Fga
  alias Mediate.Fga.Client.Http
  alias Mediate.Fga.Model
  alias Mediate.Test

  @doc "Creates the store, binds the current process to it, and pins the boot model in it."
  @spec setup(map()) :: :ok
  def setup(_tags) do
    server = Dev.Fga.info()
    {:ok, store} = Http.create_store(server.address, name())
    {:ok, model} = Http.write_model(server.address, store, Model.read!(ExampleFga.model()))
    Test.with_config(adapter: {Fga, endpoint: server.address, store_id: store, model_id: model})
  end

  defp name, do: "example-fga-#{System.unique_integer([:positive])}"
end
