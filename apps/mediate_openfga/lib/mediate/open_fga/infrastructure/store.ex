defmodule Mediate.OpenFGA.Infrastructure.Store do
  @moduledoc false
  # The store as this engine touches it. The configuration and the binding
  # together say which store it is. This module reads what it holds for one
  # object, and tells it what to hold so that it holds what the tables
  # require.
  #
  # Every call to the server is here. The arithmetic of a difference is
  # `Mediate.OpenFGA.Domain.Difference`'s, and its tests need no server.
  # What is left is a read of a page, a write of a call, and the order the
  # two go in, which needs one.
  #
  # This module brings each object into step on its own. It reads the
  # tuples the object's rows require from the tables. It reads the tuples
  # the store holds for it from the server. It writes the difference. It
  # turns nothing about a change into a write directly. That is why the
  # same marker twice costs a read and no write.

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Client
  alias Mediate.OpenFGA.Client.Page
  alias Mediate.OpenFGA.Client.Read
  alias Mediate.OpenFGA.Client.Write
  alias Mediate.OpenFGA.Domain.Difference
  alias Mediate.OpenFGA.Drift
  alias Mediate.OpenFGA.TupleKey

  @enforce_keys [:client, :address, :store_id, :mapping, :repo, :batch]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          client: module(),
          address: Client.address(),
          store_id: Client.store_id(),
          mapping: module(),
          repo: module(),
          batch: pos_integer()
        }

  @doc """
  The store the configuration entry and the binding together describe. The
  engine is the caller's to name. A configuration that names another
  engine answers an error, since the store this writes is not the one that
  answers questions.
  """
  @spec resolve(module()) :: {:ok, t()} | {:error, Error.t()}
  def resolve(engine) when is_atom(engine) do
    with {:ok, %Binding{} = binding} <- Binding.resolve(),
         {:ok, %Config{} = config} <- Config.resolve(),
         {:ok, options} <- entry(config, engine) do
      {:ok, built(binding, options)}
    end
  end

  @doc """
  The store the configuration describes, whichever engine it names. What a
  sync writes is the store that answers questions. The configuration says
  which engine that is, not the caller. So a runner delivers a marker and
  names no engine of its own.
  """
  @spec configured() :: {:ok, t()} | {:error, Error.t()}
  def configured do
    with {:ok, %Config{} = config} <- Config.resolve() do
      {engine, _options} = Config.engine(config)

      resolve(engine)
    end
  end

  @doc "Every object of every type the mapping names, in the order the mapping gives them."
  @spec objects(t()) :: [String.t()]
  def objects(%__MODULE__{} = store) do
    Enum.flat_map(store.mapping.object_types(), &store.mapping.objects(store.repo, &1))
  end

  @doc "Brings each object into step with what its rows require, one object at a time."
  @spec sync(t(), [String.t()]) :: :ok | {:error, Error.t()}
  def sync(%__MODULE__{} = store, objects) when is_list(objects) do
    Enum.reduce_while(objects, :ok, fn object, :ok ->
      case object(store, object) do
        :ok -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  @doc "The tuples every table requires against the tuples the store holds, as of this position."
  @spec drift(t(), non_neg_integer()) :: {:ok, Drift.t()} | {:error, Error.t()}
  def drift(%__MODULE__{} = store, position) when is_integer(position) do
    with {:ok, present} <- present(store) do
      wanted =
        store
        |> objects()
        |> Enum.flat_map(&store.mapping.tuples(store.repo, &1))
        |> MapSet.new()

      have = MapSet.new(present)

      {:ok,
       %Drift{
         missing: Difference.sorted(MapSet.difference(wanted, have)),
         extra: Difference.sorted(MapSet.difference(have, wanted)),
         position: position
       }}
    end
  end

  @doc "A store of this name that carries the bound model, for a rebuild to write into."
  @spec create(t(), String.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def create(%__MODULE__{} = store, name, model) when is_binary(name) do
    with {:ok, store_id} <- store.client.create_store(store.address, name),
         {:ok, _model_id} <- store.client.write_authorization_model(store.address, store_id, model) do
      {:ok, %{store | store_id: store_id}}
    end
  end

  @doc "The tuples the store holds for one object, paged."
  @spec held(t(), String.t()) :: {:ok, [TupleKey.t()]} | {:error, Error.t()}
  def held(%__MODULE__{} = store, object) when is_binary(object) do
    [type | id] = String.split(object, ":", parts: 2)

    pages(store, %Read{object_type: type, object_id: List.first(id), page_size: store.batch}, [])
  end

  @doc """
  Every tuple of every type the mapping names, which is what the store
  holds of its own. A type the mapping leaves out is a type this engine
  does not write, and a reconcile says nothing about one.
  """
  @spec present(t()) :: {:ok, [TupleKey.t()]} | {:error, Error.t()}
  def present(%__MODULE__{} = store) do
    Enum.reduce_while(store.mapping.object_types(), {:ok, []}, fn type, {:ok, done} ->
      case pages(store, %Read{object_type: type, page_size: store.batch}, []) do
        {:ok, tuples} -> {:cont, {:ok, done ++ tuples}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp object(%__MODULE__{} = store, object) do
    with {:ok, present} <- held(store, object) do
      {deletes, writes} = Difference.between(store.mapping.tuples(store.repo, object), present)

      calls(store, Difference.writes(deletes, writes, store.batch))
    end
  end

  defp calls(_store, []), do: :ok

  defp calls(%__MODULE__{} = store, [%Write{} = call | rest]) do
    case store.client.write(store.address, store.store_id, call) do
      {:ok, _count} -> calls(store, rest)
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp pages(%__MODULE__{} = store, %Read{} = request, done) do
    case store.client.read(store.address, store.store_id, request) do
      {:ok, %Page{continuation_token: nil} = page} ->
        {:ok, Enum.concat(Enum.reverse([page.tuples | done]))}

      {:ok, %Page{} = page} ->
        pages(store, %{request | continuation_token: page.continuation_token}, [page.tuples | done])

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp built(%Binding{} = binding, options) do
    %__MODULE__{
      client: Keyword.get(options, :client, Client.HTTP),
      address: Keyword.fetch!(options, :address),
      store_id: Keyword.fetch!(options, :store_id),
      mapping: binding.mapping,
      repo: binding.repo,
      batch: Client.max_tuples_per_write()
    }
  end

  defp entry(%Config{} = config, engine) do
    case Config.engine(config) do
      {^engine, options} -> {:ok, options}
      {other, _options} -> {:error, Error.invalid(:store, "#{inspect(other)} is the configured engine, not this one")}
    end
  end
end
