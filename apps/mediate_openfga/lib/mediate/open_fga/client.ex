defmodule Mediate.OpenFGA.Client do
  @moduledoc """
  The only path to the server. Every call the engine and a sync make is a
  callback here, named as OpenFGA names the endpoint. So a suite runs
  either of them against `Mediate.OpenFGA.Client.Fake` without a server,
  and the real client is the same six calls over HTTP.

  Two arguments come before the request in every call. The address is
  where the server answers: the host and port of a real one, or the agent
  a fake runs on. The store id names the store the server keeps the
  tuples in. So a test that wants tuples of its own creates a store of its
  own and cleans nothing up.

  Each call answers `{:ok, value}` or an engine error, and none of them
  raises. A server that cannot be reached, a store that is absent, and a
  write the server refuses are all values the caller decides about.

  A model id is a value on the request and not state on the client,
  because a verdict names the version it ran under. A request that names
  none asks under the model the store last wrote.
  """

  alias Mediate.Error
  alias Mediate.OpenFGA.Client.Check
  alias Mediate.OpenFGA.Client.ListObjects
  alias Mediate.OpenFGA.Client.Page
  alias Mediate.OpenFGA.Client.Read
  alias Mediate.OpenFGA.Client.Write

  @max_tuples_per_write 100

  # The engine an error from here names. The name comes from this module's
  # own name, not from a literal. A behaviour that named the engine depends
  # on the module that implements it, and that module depends on this one.
  @engine __MODULE__
          |> Module.split()
          |> Enum.drop(-1)
          |> Module.concat()

  @typedoc "Where the server answers: a host and port, or the process a fake runs on."
  @type address :: String.t() | pid() | GenServer.name()

  @typedoc "The id of the store the tuples live in."
  @type store_id :: String.t()

  @typedoc "The id the server gave a model."
  @type model_id :: String.t()

  @typedoc "What a callback returns when the server refuses or cannot be reached."
  @type failure :: {:error, Error.t()}

  @doc "Creates a store of the given name and answers the id the server gave it."
  @callback create_store(address(), String.t()) :: {:ok, store_id()} | failure()

  @doc "Writes the model into the store and answers the id the server keeps it under."
  @callback write_authorization_model(address(), store_id(), map()) :: {:ok, model_id()} | failure()

  @doc "Whether one tuple holds."
  @callback check(address(), store_id(), Check.t()) :: {:ok, boolean()} | failure()

  @doc "The objects of one type the user holds one relation on."
  @callback list_objects(address(), store_id(), ListObjects.t()) :: {:ok, [String.t()]} | failure()

  @doc "One page of the tuples the store holds."
  @callback read(address(), store_id(), Read.t()) :: {:ok, Page.t()} | failure()

  @doc "Applies the deletes and the writes of one call together and answers how many changes it carried."
  @callback write(address(), store_id(), Write.t()) :: {:ok, non_neg_integer()} | failure()

  @doc """
  How many changes one `write/3` carries at most, its deletes and its
  writes counted together. This is the server's own limit. The fake holds
  callers to it, and a sync packs its calls under it.
  """
  @spec max_tuples_per_write() :: pos_integer()
  def max_tuples_per_write, do: @max_tuples_per_write

  @doc "An engine error, which names the engine and the operation it failed during."
  @spec error(atom(), String.t()) :: Error.t()
  def error(operation, text) when is_atom(operation) and is_binary(text) do
    %Error{reason: :engine_failed, message: "#{inspect(@engine)} failed during #{operation}: #{text}"}
  end
end
