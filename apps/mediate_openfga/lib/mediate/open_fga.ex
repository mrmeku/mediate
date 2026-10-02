defmodule Mediate.OpenFGA do
  @moduledoc """
  OpenFGA: the engine whose rules are a relationship model in a store an
  OpenFGA server holds.

  The configuration boots with `engine: {Mediate.OpenFGA, address:
  "127.0.0.1:8080", store_id: "01J...", model_id: "01K..."}`
  (`Mediate.Config`). The entry carries where the server answers, the
  store the tuples live in, and the model every question runs under. The
  rest comes from the binding `Mediate.OpenFGA.Binding.bind/1` makes at
  boot: the mediated repo, the model file, the mapping, the guard, and
  who wrote and approved the model.

  Facts become tuples in the store. Rules become a model the server keeps
  under an id. A decision is one `Check` under the pinned model at the
  higher consistency. A filter is one `ListObjects` at the lower
  consistency, turned into a `dynamic` over ids. The filter limit is
  1,000, the server's own limit on one listing. At the limit the listing
  may be short of the truth and says nothing about it, so `filter/5`
  fails and the library authorizes each row instead.

  The store is a copy of the application's tables, and the engine decides
  from the copy. `Mediate.OpenFGA.Outbox` marks every object a write
  affected, in the write's transaction, and a `Mediate.Relay` runner
  delivers the markers: a pass reads what each object requires from the
  tables and writes the difference to the store. `sync/0` runs passes
  until no marker is left, for a caller that has written facts and wants
  to ask about them.

  The modules a deployment names:

  - `Mediate.OpenFGA.Client`, the only path to the server.
    `Mediate.OpenFGA.Client.Fake` is the same behaviour on an agent.
  - `Mediate.OpenFGA.Mapping`, what the deployment states about its tables.
  - `Mediate.OpenFGA.Outbox`, the markers a sync works from, and the
    `Mediate.Relay.Job` that delivers them.
  - `Mediate.OpenFGA.Binding`, what the configuration entry does not carry.
  - `Mediate.OpenFGA.Guard`, a precondition on the context, for a fact
    about the call that no tuple carries.
  - `Mediate.OpenFGA.Version`, the model as a policy release.
  - `Mediate.OpenFGA.Migration` and `Mediate.Relay.Migration`, the outbox
    table and the cursor table, which a deployment's migration creates.
  - `Mediate.OpenFGA.OutboxCase` and `Mediate.OpenFGA.MappingCase`, the
    case templates that hold a deployment's outbox and mapping to what a
    sync relies on. Both write and clear a `Mediate.OpenFGA.Population`.
  """

  @behaviour Mediate.Engine

  use Boundary,
    deps: [Mediate, Mediate.Relay, Ecto, NimbleOptions],
    exports: [
      Binding,
      Client,
      Client.Check,
      Client.HTTP,
      Client.ListObjects,
      Client.Page,
      Client.Read,
      Client.Write,
      Condition,
      Consistency,
      Drift,
      Guard,
      Mapping,
      MappingCase,
      Model,
      Outbox,
      OutboxCase,
      Population,
      TupleKey,
      Version
    ]

  alias Mediate.Error
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Drift
  alias Mediate.OpenFGA.Infrastructure.Decide
  alias Mediate.OpenFGA.Infrastructure.Release
  alias Mediate.OpenFGA.Infrastructure.Store
  alias Mediate.OpenFGA.Infrastructure.Sync
  alias Mediate.OpenFGA.Model
  alias Mediate.OpenFGA.Outbox
  alias Mediate.OpenFGA.Version
  alias Mediate.PolicyRelease
  alias Mediate.Relay.Cursor

  @schema NimbleOptions.new!(
            address: [
              type: :any,
              required: true,
              doc: "Where the server answers: a host and port such as `127.0.0.1:8080`, or the process a fake runs on."
            ],
            store_id: [type: :string, required: true, doc: "The store a sync writes and a decision reads."],
            model_id: [
              type: :string,
              doc:
                "The model the entry pins every question to. Absent until the first release. " <>
                  "A decision under an entry that pins none fails closed."
            ],
            client: [
              type: :atom,
              doc: "The `Mediate.OpenFGA.Client` implementation. `Mediate.OpenFGA.Client.HTTP` when absent."
            ]
          )

  @doc """
  Writes the bound model to the store and publishes the release the server
  names it by. `Mediate.OpenFGA.Version` says what the release holds.
  """
  @spec release() :: {:ok, PolicyRelease.t()} | {:error, Error.t()}
  def release, do: Release.publish(__MODULE__)

  @doc """
  Marks every object of every type the mapping names. The next sync then
  brings the store to what the tables require for all of them. This fills
  a store whose rows predate the handler. A test calls it after it wrote
  rows the handler did not see.
  """
  @spec mark_all() :: :ok | {:error, Error.t()}
  def mark_all do
    with {:ok, %Store{} = store} <- Store.resolve(__MODULE__) do
      Outbox.mark(store.repo, Store.objects(store))
    end
  end

  @doc """
  The tuples the tables require against the tuples the store holds, as of
  the position the runner has delivered to. An empty drift says the two
  agree. A drift that is not empty names every tuple that differs.
  """
  @spec reconcile() :: {:ok, Drift.t()} | {:error, Error.t()}
  def reconcile do
    with {:ok, %Store{} = store} <- Store.resolve(__MODULE__) do
      Store.drift(store, Cursor.position(store.repo, Outbox.runner()))
    end
  end

  @doc """
  Creates a store of this name, writes the bound model into it, writes
  every tuple the tables require, and answers the new store's id. The
  store the configuration names serves on while this one fills. So a
  rebuild is a store to point the configuration at, not an outage.

  A rebuild writes every object directly and not through the outbox. A
  second store on the same cursor finds only the markers the first sync
  left, and the first sync deletes what it delivered.
  """
  @spec rebuild(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def rebuild(name \\ "mediate") when is_binary(name) do
    with {:ok, %Binding{} = binding} <- Binding.resolve(),
         {:ok, text} <- Version.text(binding),
         {:ok, model} <- Model.compile(text),
         {:ok, %Store{} = store} <- Store.resolve(__MODULE__),
         {:ok, %Store{} = fresh} <- Store.create(store, name, model),
         :ok <- Store.sync(fresh, Store.objects(fresh)) do
      {:ok, fresh.store_id}
    end
  end

  @impl Mediate.Engine
  def options_schema, do: @schema

  @impl Mediate.Engine
  def filter_limit, do: Decide.limit()

  @impl Mediate.Engine
  def sync, do: Sync.run()

  @impl Mediate.Engine
  def authorize({_kind, _account} = subject, action, {_type, _id} = resource, %{now: _now} = context, options)
      when is_atom(action) do
    case entry(options, :authorize, action, context) do
      {:ok, entry} -> Decide.one(entry, subject, action, resource)
      {:refused, entry} -> {:ok, Decide.refused(entry)}
      {:error, error} -> {:error, error}
    end
  end

  @impl Mediate.Engine
  def filter({_kind, _account} = subject, action, resource_type, %{now: _now} = context, options)
      when is_atom(action) and is_atom(resource_type) do
    case entry(options, :filter, action, context) do
      {:ok, entry} -> Decide.filter(entry, subject, action, resource_type)
      {:refused, entry} -> {:ok, Decide.refused_filter(entry)}
      {:error, error} -> {:error, error}
    end
  end

  # The engine asks the guard before any question goes to the server. So it
  # resolves the binding first, and a refusal carries the entry the denial
  # reports under. Nothing else reads here: a decision is one call to the
  # store and no query of its own.
  defp entry(options, callback, action, context) do
    with {:ok, %Binding{} = binding} <- bound(callback),
         {:ok, entry} <- Decide.entry(options, callback, context) do
      admits(binding, action, context, entry)
    end
  end

  defp admits(%Binding{guard: nil}, _action, _context, entry), do: {:ok, entry}

  defp admits(%Binding{guard: guard}, action, %{now: _now} = context, entry) do
    if guard.admits?(action, context), do: {:ok, entry}, else: {:refused, entry}
  end

  defp bound(callback) do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> {:ok, binding}
      {:error, %Error{reason: :invalid, message: message}} -> {:error, failed(callback, message)}
    end
  end

  defp failed(callback, text) do
    %Error{reason: :engine_failed, message: "#{inspect(__MODULE__)} failed during #{callback}: #{text}"}
  end
end
