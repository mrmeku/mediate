defmodule ExampleOpenFGA.Store do
  @moduledoc """
  A store of each test's own, with the boot model in it and pinned for the
  current process.

  The store is per test because it is the engine's copy of the facts. Two
  tests that write tuples into one store read each other's, whatever the
  database does with their rows. `setup/1` creates the store and writes the
  boot model into it, so every check the test runs asks a model of its own.

  Every scenario that writes a fact syncs the store before it asks. A tuple
  reaches the store by a pass and not by the write.
  """

  use Boundary, top_level?: true, deps: [ExampleOpenFGA, Mediate, Mediate.OpenFGA, Mediate.Test]

  alias Mediate.Dev
  alias Mediate.OpenFGA
  alias Mediate.OpenFGA.Client.HTTP
  alias Mediate.OpenFGA.Model
  alias Mediate.Test

  @doc "Creates the store, binds the current process to it, and pins the boot model in it."
  @spec setup(map()) :: :ok
  def setup(_tags) do
    server = Dev.OpenFGA.current!()
    {:ok, store} = HTTP.create_store(server.http, name())
    {:ok, model} = HTTP.write_authorization_model(server.http, store, Model.read!(ExampleOpenFGA.model_file()))
    Test.with_config(engine: {OpenFGA, address: server.http, store_id: store, model_id: model})
  end

  defp name, do: "example-openfga-#{System.unique_integer([:positive])}"
end
