defmodule Mediate.Fga.Outbox do
  @moduledoc """
  The markers a drain works from: one row per object whose tuples can have
  fallen behind the tables. The handler writes the row in the transaction
  that changed them.

  `attach/0` puts a handler on `Mediate.Change.event()`. The handler asks
  the bound mapping which objects a change can have affected. It inserts a
  marker for each, on the connection the change ran on. A change that does
  not commit takes its markers with it. A marker that commits arrives at
  least once.

  A marker says which object to look at and nothing more. The drain reads
  what that object requires from the tables when the marker arrives. So a
  marker that arrives twice costs a read and no write.

  Delivery is a `Mediate.Fga.Relay.Job`. One pass, in one transaction:

  - reads a batch of markers above the cursor
  - takes the distinct objects in it
  - brings the store to what the tables require for each
  - deletes the markers it delivered

  A pass that does not commit leaves the markers and the cursor where they
  were. A thin application puts the runner in its tree and gives the job no
  options of its own:

  ```elixir
  {Mediate.Fga.Relay,
   runners: [
     [name: Mediate.Fga.Outbox.runner(), repo: MyApp.Repo, job: Mediate.Fga.Outbox]
   ]}
  ```

  The store a pass writes is the one the configuration names. The pass
  resolves it, and the runner names none. The pass reads the tables on its
  own connection. So the tuples it writes are the tuples those rows require
  at the moment of the read.

  A marker names an object and says nothing about who can reach it. So
  writes to this table carry the library exemption and not a decision.

  `:telemetry` detaches a handler that raises, and a detached handler is a
  store that falls behind in silence. The handler here answers `:ok`
  whatever happens and reports a failure as `unmarked_event/0` instead. The
  change itself survives. The insert runs in the write's transaction, so a
  failed insert takes the write down with it. A failure before the insert
  leaves the change unmarked, which is drift `Mediate.Fga.reconcile/0`
  reports.
  """

  @behaviour Mediate.Fga.Relay.Job

  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  alias Mediate.Change
  alias Mediate.Error
  alias Mediate.Fga.Binding
  alias Mediate.Fga.Infrastructure.Store
  alias Mediate.Fga.Relay.Entry
  alias Mediate.Fga.Relay.Job

  @exemption {:exempt, :library}
  @handler {__MODULE__, :change}
  @runner :mediate_fga
  @table "mediate_fga_outbox"
  @unmarked [:mediate, :fga, :unmarked]

  @schema NimbleOptions.new!([])

  schema @table do
    field(:object, :string)
  end

  @type t :: %__MODULE__{}

  @doc "The name of the runner's cursor. The runner a thin application starts must use it too."
  @spec runner() :: atom()
  def runner, do: @runner

  @doc "The table the handler writes the markers to."
  @spec table() :: String.t()
  def table, do: @table

  @doc "The event the handler emits for a change it did not mark. It carries the change and the exception."
  @spec unmarked_event() :: [atom()]
  def unmarked_event, do: @unmarked

  @doc "Marks every change from now on. A second call leaves one handler."
  @spec attach() :: :ok
  def attach do
    case :telemetry.attach(@handler, Change.event(), &__MODULE__.__change__/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  @doc "Detaches the handler, so changes no longer leave markers."
  @spec detach() :: :ok
  def detach do
    _detached = :telemetry.detach(@handler)
    :ok
  end

  @doc "Marks these objects, so the next drain brings the store to what their rows require."
  @spec mark(module(), [String.t()]) :: :ok
  def mark(repo, objects) when is_atom(repo) and is_list(objects) do
    case Enum.map(objects, &%{object: &1}) do
      [] -> :ok
      rows -> marked(repo, rows)
    end
  end

  @doc false
  @spec __change__([atom()], map(), map(), term()) :: :ok
  def __change__(_event, _measurements, change, _config) do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> mark(binding.repo, binding.mapping.changed(binding.repo, change))
      {:error, %Error{} = error} -> raise error
    end
  rescue
    exception ->
      :telemetry.execute(@unmarked, %{}, %{change: change, exception: exception})
      :ok
  end

  @impl Job
  def options_schema, do: @schema

  @impl Job
  def read(repo, _options, from, limit) do
    query = from(marker in __MODULE__, where: marker.id > ^from, order_by: [asc: marker.id], limit: ^limit)

    entries =
      for marker <- repo.all(query, mediate: @exemption), do: %Entry{position: marker.id, payload: marker.object}

    {:ok, entries}
  end

  @impl Job
  def deliver(repo, _options, entries) do
    objects =
      entries
      |> Enum.map(& &1.payload)
      |> Enum.uniq()

    with {:ok, store} <- Store.configured(),
         :ok <- Store.converge(%{store | repo: repo}, objects) do
      forget(repo, entries)
    end
  end

  defp marked(repo, rows) do
    {_written, nil} = repo.insert_all(__MODULE__, rows, mediate: @exemption)
    :ok
  end

  defp forget(repo, entries) do
    positions = Enum.map(entries, & &1.position)
    delivered = from(marker in __MODULE__, where: marker.id in ^positions)
    {_deleted, nil} = repo.delete_all(delivered, mediate: @exemption)

    :ok
  end
end
