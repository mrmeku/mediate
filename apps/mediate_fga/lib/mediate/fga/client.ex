defmodule Mediate.Fga.Client do
  @moduledoc """
  The only path to the server. Every call the adapter and the drain make
  is a callback here. So a suite runs either of them against
  `Mediate.Fga.Client.Fake` without a server, and the real client is the
  same six calls over HTTP.

  Two arguments come before the request in every call. The endpoint is
  where the server is: the address of a real one, or the agent a fake runs
  on. The store is the isolation unit the server keeps tuples in. So a test
  that wants tuples of its own creates a store of its own and cleans
  nothing up.

  Each call answers `{:ok, value}` or an engine error, and none of them
  raises. A server that is unreachable, a store that is absent, and a
  write the server refuses are all values the caller decides about.

  A model id is a value on the request and not state on the client,
  because a decision names the version it ran under. A request that names
  none asks under the model the store last published.
  """

  alias Mediate.Error
  alias Mediate.Fga.Client.Check
  alias Mediate.Fga.Client.ListObjects
  alias Mediate.Fga.Client.Page
  alias Mediate.Fga.Client.Read
  alias Mediate.Fga.Client.Write

  @max_tuples_per_write 100

  # The adapter an engine error from here names. The name comes from this
  # module's own name, not from a literal. A behaviour that named the
  # adapter depends on the module that implements it, and that module
  # depends on this one.
  @adapter __MODULE__
           |> Module.split()
           |> Enum.drop(-1)
           |> Module.concat()

  @typedoc "Where the server is: the address of one, or the process a fake runs on."
  @type endpoint :: String.t() | pid() | GenServer.name()

  @typedoc "The store tuples live in."
  @type store :: String.t()

  @typedoc "The id of a published model."
  @type model :: String.t()

  @type failure :: {:error, Error.t()}

  @doc "Creates a store of the given name and answers the id the server gave it."
  @callback create_store(endpoint(), String.t()) :: {:ok, store()} | failure()

  @doc "Publishes the model into the store and answers the id the server keeps it under."
  @callback write_model(endpoint(), store(), map()) :: {:ok, model()} | failure()

  @doc "Whether one tuple holds."
  @callback check(endpoint(), store(), Check.t()) :: {:ok, boolean()} | failure()

  @doc "The objects of one type the user holds one relation on."
  @callback list_objects(endpoint(), store(), ListObjects.t()) :: {:ok, [String.t()]} | failure()

  @doc "One page of the tuples the store holds."
  @callback read(endpoint(), store(), Read.t()) :: {:ok, Page.t()} | failure()

  @doc "Applies the deletes and the writes of one call together and answers how many changes it carried."
  @callback write(endpoint(), store(), Write.t()) :: {:ok, non_neg_integer()} | failure()

  @doc """
  How many changes one `write/3` carries at most, its deletes and its
  writes counted together. This is the pinned server's own limit. The fake
  holds callers to it, and the drain packs its calls under it.
  """
  @spec max_tuples_per_write() :: pos_integer()
  def max_tuples_per_write, do: @max_tuples_per_write

  @doc "An engine error from this adapter, which names the call it came from."
  @spec error(atom(), String.t()) :: Error.t()
  def error(operation, detail) when is_atom(operation) and is_binary(detail) do
    %Error{reason: :engine_unreachable, detail: "#{inspect(@adapter)} failed during #{operation}: #{detail}"}
  end
end
