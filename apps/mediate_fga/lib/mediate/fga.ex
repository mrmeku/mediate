defmodule Mediate.Fga do
  @moduledoc """
  The OpenFGA adapter. Facts become tuples in a store of the engine's own.
  Rules become a model that is immutable and that an id names. A drain
  keeps the store in step with the application's tables. So this adapter
  decides from a copy and not from the tables themselves.

  An operation is a relation of the model: `can_` and the operation's name.
  A decision is one `Check` under the model the configuration pins, at the
  higher consistency. A scope is one `ListObjects` at the lower
  consistency, turned into a `dynamic` over identifiers. The scope cap is
  1,000, the pinned server's own limit on one `ListObjects`. At the cap or
  above it the answer is short of the truth and says nothing about it. So
  `scope` emits `[:mediate, :fga, :scope_fallback]` and fails, and the
  caller asks per row.

  `settle/0` drains the outbox until nothing is left.

  The modules a consumer names:

  - `Mediate.Fga.Client`, the only path to the server. `Mediate.Fga.Client.Fake`
    is the same behaviour on an `Agent`.
  - `Mediate.Fga.TupleMapping`, what an application states about its tables.
  - `Mediate.Fga.Outbox`, the markers a drain works from, and the
    `Mediate.Fga.Relay` job that delivers them.
  - `Mediate.Fga.Binding`, what the configuration entry does not carry: the
    repo, the model file, the mapping, and the guard.
  - `Mediate.Fga.Guard`, a precondition on the environment, for a fact about
    the call that no tuple carries.
  - `Mediate.Fga.Version`, the model as a policy version.
  - `Mediate.Fga.Migration`, the outbox table and the cursor table, which a
    thin application's migration creates.
  - `Mediate.Fga.OutboxCase` and `Mediate.Fga.TupleMappingCase`, the
    templates that hold an application's drain and mapping to what a
    decision relies on. Both write and take away a `Mediate.Fga.Population`.
  """

  @behaviour Mediate.Adapter

  use Boundary,
    deps: [Mediate, Mediate.Fga.Relay, Ecto, NimbleOptions],
    exports: [
      Binding,
      Client,
      Client.Check,
      Client.Http,
      Client.ListObjects,
      Client.Page,
      Client.Read,
      Client.Write,
      Condition,
      Consistency,
      Drift,
      Guard,
      Model,
      Outbox,
      OutboxCase,
      Population,
      TupleKey,
      TupleMapping,
      TupleMappingCase,
      Version
    ]

  alias Mediate.Error
  alias Mediate.Fga.Binding
  alias Mediate.Fga.Drift
  alias Mediate.Fga.Infrastructure.Decide
  alias Mediate.Fga.Infrastructure.Settle
  alias Mediate.Fga.Infrastructure.Store
  alias Mediate.Fga.Infrastructure.Version
  alias Mediate.Fga.Outbox
  alias Mediate.Fga.Relay.Cursor
  alias Mediate.PolicyVersion

  @schema NimbleOptions.new!(
            endpoint: [
              type: :any,
              required: true,
              doc: "Where the server is: the address of one, or the process a fake runs on."
            ],
            store_id: [type: :string, required: true, doc: "The store a drain writes and decisions read."],
            model_id: [
              type: :string,
              doc:
                "The model the entry pins every question to. Absent until the first publish. " <>
                  "A decision under an entry that pins none fails closed."
            ],
            client: [
              type: :atom,
              doc: "The `Mediate.Fga.Client` implementation. `Mediate.Fga.Client.Http` when absent."
            ]
          )

  @doc """
  Writes the bound model to the server and emits the version the server
  names it by. `Mediate.Fga.Version` has the version.
  """
  @spec publish() :: {:ok, PolicyVersion.t()} | {:error, Error.t()}
  def publish, do: Version.publish(__MODULE__)

  @doc """
  Marks every object of every type the mapping names. The next drain then
  brings the store to what the tables require for all of them. This fills a
  store whose rows predate the handler. A test calls it after it wrote rows
  the handler did not see.
  """
  @spec mark_all() :: :ok | {:error, Error.t()}
  def mark_all do
    with {:ok, %Store{} = store} <- Store.resolve(__MODULE__) do
      Outbox.mark(store.repo, Store.objects(store))
    end
  end

  @doc """
  The tuples the tables require against the tuples the store holds, as of
  the marker the drain has reached. A drift that is clean says the two
  agree. A drift that is not clean names every tuple that differs.
  """
  @spec reconcile() :: {:ok, Drift.t()} | {:error, Error.t()}
  def reconcile do
    with {:ok, %Store{} = store} <- Store.resolve(__MODULE__) do
      Store.drift(store, Cursor.position(store.repo, Outbox.runner()))
    end
  end

  @doc """
  Creates a store of this name, publishes the bound model into it, writes
  every tuple the tables require, and answers the new store's id. The store
  the configuration names serves on while this one fills. So a rebuild is a
  store to point the configuration at, not an outage.

  A rebuild writes every object directly and not through the outbox. A
  second store on the same cursor finds only the markers the first drain
  left, and the first drain deletes what it delivered.
  """
  @spec rebuild(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def rebuild(name \\ "mediate") when is_binary(name) do
    with {:ok, %Binding{} = binding} <- Binding.resolve(),
         {:ok, model} <- Binding.compiled(binding),
         {:ok, %Store{} = store} <- Store.resolve(__MODULE__),
         {:ok, %Store{} = fresh} <- Store.created(store, name, model),
         :ok <- Store.converge(fresh, Store.objects(fresh)) do
      {:ok, fresh.store}
    end
  end

  @impl Mediate.Adapter
  def options_schema, do: @schema

  @impl Mediate.Adapter
  def scope_cap, do: Decide.scope_cap()

  @impl Mediate.Adapter
  def settle, do: Settle.now()

  @impl Mediate.Adapter
  def decide({_kind, _account} = subject, operation, {_type, _id} = object, %{now: _now} = environment, options)
      when is_atom(operation) do
    case entry(options, :decide, operation, environment) do
      {:ok, entry} -> Decide.one(entry, subject, operation, object)
      {:refused, entry} -> {:ok, Decide.refused(entry)}
      {:error, error} -> {:error, error}
    end
  end

  @impl Mediate.Adapter
  def scope({_kind, _account} = subject, operation, object_type, %{now: _now} = environment, options)
      when is_atom(operation) and is_atom(object_type) do
    case entry(options, :scope, operation, environment) do
      {:ok, entry} -> Decide.scoped(entry, subject, operation, object_type)
      {:refused, entry} -> {:ok, Decide.refused_scope(entry)}
      {:error, error} -> {:error, error}
    end
  end

  # The adapter asks the guard before any question goes to the server. So it
  # resolves the binding first, and a refusal carries the entry the denial
  # reports under. Nothing else reads here: a decision is one call to the
  # store and no query of its own.
  defp entry(options, callback, operation, environment) do
    with {:ok, %Binding{} = binding} <- bound(callback),
         {:ok, entry} <- Decide.entry(options, callback, environment) do
      admits(binding, operation, environment, entry)
    end
  end

  defp admits(%Binding{guard: nil}, _operation, _environment, entry), do: {:ok, entry}

  defp admits(%Binding{guard: guard}, operation, %{now: _now} = environment, entry) do
    if guard.admits?(operation, environment), do: {:ok, entry}, else: {:refused, entry}
  end

  defp bound(callback) do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> {:ok, binding}
      {:error, %Error{reason: :invalid, detail: detail}} -> {:error, engine(callback, detail)}
    end
  end

  defp engine(callback, detail) do
    %Error{reason: :engine_unreachable, detail: "#{inspect(__MODULE__)} failed during #{callback}: #{detail}"}
  end
end
