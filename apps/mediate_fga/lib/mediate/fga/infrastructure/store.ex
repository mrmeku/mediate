defmodule Mediate.Fga.Infrastructure.Store do
  @moduledoc false
  # The store as this adapter touches it. The configuration and the binding
  # together say which store it is. This module reads what it holds for one
  # object, and tells it what to hold so that it holds what the tables
  # require.
  #
  # Every call to the server is here. The arithmetic of a difference is
  # `Mediate.Fga.Domain.Drain`'s, and its tests need no server. What is
  # left is a read of a page, a write of a call, and the order the two go
  # in, which needs one.
  #
  # This module brings each object into step on its own. It reads the
  # tuples the object's rows require from the tables. It reads the tuples
  # the store holds for it from the server. It writes the difference. It turns
  # nothing about a change into a write directly. That is why the same
  # marker twice costs a read and no write.

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.Fga.Binding
  alias Mediate.Fga.Client
  alias Mediate.Fga.Client.Page
  alias Mediate.Fga.Client.Read
  alias Mediate.Fga.Client.Write
  alias Mediate.Fga.Domain.Drain
  alias Mediate.Fga.Drift
  alias Mediate.Fga.TupleKey

  @enforce_keys [:client, :endpoint, :store, :mapping, :repo, :batch]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          client: module(),
          endpoint: Client.endpoint(),
          store: Client.store(),
          mapping: module(),
          repo: module(),
          batch: pos_integer()
        }

  @doc """
  The store the configuration entry and the binding together describe. The
  adapter is the caller's to name. A configuration that names another
  adapter answers an error, since the store this writes is not the one that
  answers questions.
  """
  @spec resolve(module()) :: {:ok, t()} | {:error, Error.t()}
  def resolve(adapter) when is_atom(adapter) do
    with {:ok, %Binding{} = binding} <- Binding.resolve(),
         {:ok, %Config{} = config} <- Config.resolve(),
         {:ok, options} <- entry(config, adapter) do
      {:ok, built(binding, options)}
    end
  end

  @doc """
  The store the configuration describes, whichever adapter it names. What a
  drain writes is the store that answers questions. The configuration says
  which adapter that is, not the caller. So a runner delivers a marker and
  names no adapter of its own.
  """
  @spec configured() :: {:ok, t()} | {:error, Error.t()}
  def configured do
    with {:ok, %Config{} = config} <- Config.resolve() do
      {adapter, _options} = Config.adapter(config)

      resolve(adapter)
    end
  end

  @doc "Every object of every type the mapping names, in the order the mapping gives them."
  @spec objects(t()) :: [String.t()]
  def objects(%__MODULE__{} = store) do
    Enum.flat_map(store.mapping.object_types(), &store.mapping.objects(store.repo, &1))
  end

  @doc "Brings each object into step with what its rows require, one object at a time."
  @spec converge(t(), [String.t()]) :: :ok | {:error, Error.t()}
  def converge(%__MODULE__{} = store, objects) when is_list(objects) do
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
         missing: Drain.sorted(MapSet.difference(wanted, have)),
         extra: Drain.sorted(MapSet.difference(have, wanted)),
         checked_to: position
       }}
    end
  end

  @doc "A store of this name that carries the bound model, for a rebuild to write into."
  @spec created(t(), String.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def created(%__MODULE__{} = store, name, model) when is_binary(name) do
    with {:ok, reference} <- store.client.create_store(store.endpoint, name),
         {:ok, _model} <- store.client.write_model(store.endpoint, reference, model) do
      {:ok, %{store | store: reference}}
    end
  end

  @doc "The tuples the store holds for one object, paged."
  @spec held(t(), String.t()) :: {:ok, [TupleKey.t()]} | {:error, Error.t()}
  def held(%__MODULE__{} = store, object) when is_binary(object) do
    [type | id] = String.split(object, ":", parts: 2)

    pages(store, %Read{object_type: type, object_id: List.first(id), limit: store.batch}, [])
  end

  @doc """
  Every tuple of every type the mapping names, which is what the store holds
  of its own. A type the mapping leaves out is a type this adapter does not
  write, and a reconcile says nothing about one.
  """
  @spec present(t()) :: {:ok, [TupleKey.t()]} | {:error, Error.t()}
  def present(%__MODULE__{} = store) do
    Enum.reduce_while(store.mapping.object_types(), {:ok, []}, fn type, {:ok, done} ->
      case pages(store, %Read{object_type: type, limit: store.batch}, []) do
        {:ok, tuples} -> {:cont, {:ok, done ++ tuples}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp object(%__MODULE__{} = store, object) do
    with {:ok, present} <- held(store, object) do
      {deletes, writes} = Drain.difference(store.mapping.tuples(store.repo, object), present)

      calls(store, Drain.calls(deletes, writes, store.batch))
    end
  end

  defp calls(_store, []), do: :ok

  defp calls(%__MODULE__{} = store, [%Write{} = call | rest]) do
    case store.client.write(store.endpoint, store.store, call) do
      {:ok, _count} -> calls(store, rest)
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp pages(%__MODULE__{} = store, %Read{} = request, done) do
    case store.client.read(store.endpoint, store.store, request) do
      {:ok, %Page{continuation: nil} = page} -> {:ok, Enum.concat(Enum.reverse([page.tuples | done]))}
      {:ok, %Page{} = page} -> pages(store, %{request | continuation: page.continuation}, [page.tuples | done])
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp built(%Binding{} = binding, options) do
    %__MODULE__{
      client: Keyword.get(options, :client, Client.Http),
      endpoint: Keyword.fetch!(options, :endpoint),
      store: Keyword.fetch!(options, :store_id),
      mapping: binding.mapping,
      repo: binding.repo,
      batch: Client.max_tuples_per_write()
    }
  end

  defp entry(%Config{} = config, adapter) do
    case Config.adapter(config) do
      {^adapter, options} -> {:ok, options}
      {other, _options} -> {:error, Error.invalid(:store, "#{inspect(other)} is the configured adapter, not this one")}
    end
  end
end
