defmodule Mediate.OpenFGA.Outbox do
  @moduledoc """
  The markers a sync works from: one row per object whose tuples can have
  fallen behind the tables. The handler writes the row in the transaction
  that changed them.

  `attach/0` puts a handler on `Mediate.IdentityWrite.event()`. The
  handler asks the bound mapping which objects a write can have affected.
  It inserts a marker for each, on the connection the write ran on. A
  write that does not commit takes its markers with it. A marker that
  commits arrives at least once.

  A marker says which object to look at and nothing more. A pass reads
  what that object requires from the tables when the marker arrives. So a
  marker that arrives twice costs a read and no write.

  Delivery is a `Mediate.Relay.Job`. One pass, in one transaction:

  - reads a batch of markers above the cursor
  - takes the distinct objects in it
  - brings the store to what the tables require for each
  - deletes the markers it delivered

  A pass that does not commit leaves the markers and the cursor where they
  were. A deployment puts the runner in its tree and gives the job no
  options of its own:

  ```elixir
  {Mediate.Relay,
   runners: [
     [name: Mediate.OpenFGA.Outbox.runner(), repo: MyApp.Repo, job: Mediate.OpenFGA.Outbox]
   ]}
  ```

  The store a pass writes is the one the configuration names. The pass
  resolves it, and the runner names none. The pass reads the tables on
  its own connection. So the tuples it writes are the tuples those rows
  require at the moment of the read.

  A marker names an object and says nothing about who can reach it. So
  writes to this table carry the library exemption and not a decision.

  `:telemetry` detaches a handler that raises, and a detached handler is a
  store that falls behind in silence. The handler here answers `:ok`
  whatever happens and reports a failure as `event/0` instead. The write
  itself survives. The insert runs in the write's transaction, so a failed
  insert takes the write down with it. A failure before the insert leaves
  the write unmarked, which is drift `Mediate.OpenFGA.reconcile/0`
  reports.
  """

  @behaviour Mediate.Relay.Job

  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  alias Mediate.Error
  alias Mediate.IdentityWrite
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Infrastructure.Store
  alias Mediate.Relay.Entry
  alias Mediate.Relay.Job

  @exemption {:exempt, :library}
  @handler {__MODULE__, :identity_write}
  @runner :mediate_openfga
  @table "mediate_openfga_outbox"
  @unmarked [:mediate, :openfga, :unmarked]

  @schema NimbleOptions.new!([])

  schema @table do
    field(:object, :string)
  end

  @typedoc "One marker row."
  @type t :: %__MODULE__{}

  @doc "The name of the runner's cursor. The runner a deployment starts must use it too."
  @spec runner() :: atom()
  def runner, do: @runner

  @doc "The table the handler writes the markers to."
  @spec table() :: String.t()
  def table, do: @table

  @doc "The event the handler emits for a write it did not mark. It carries the write and the exception."
  @spec event() :: [atom()]
  def event, do: @unmarked

  @doc "Marks every identity write from now on. A second call leaves one handler."
  @spec attach() :: :ok
  def attach do
    case :telemetry.attach(@handler, IdentityWrite.event(), &__MODULE__.handle_event/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  @doc "Detaches the handler, so writes no longer leave markers."
  @spec detach() :: :ok
  def detach do
    _detached = :telemetry.detach(@handler)
    :ok
  end

  @doc "Marks these objects, so the next sync brings the store to what their rows require."
  @spec mark(module(), [String.t()]) :: :ok
  def mark(repo, objects) when is_atom(repo) and is_list(objects) do
    case Enum.map(objects, &%{object: &1}) do
      [] -> :ok
      rows -> marked(repo, rows)
    end
  end

  @doc false
  @spec handle_event([atom()], map(), map(), term()) :: :ok
  def handle_event(_event, _measurements, write, _config) do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> mark(binding.repo, binding.mapping.affected(binding.repo, write))
      {:error, %Error{} = error} -> raise error
    end
  rescue
    exception ->
      :telemetry.execute(@unmarked, %{}, %{write: write, exception: exception})
      :ok
  end

  @impl Job
  def options_schema, do: @schema

  @impl Job
  def read(repo, _options, from, limit) do
    query = from(marker in __MODULE__, where: marker.id > ^from, order_by: [asc: marker.id], limit: ^limit)

    entries =
      for marker <- repo.all(query, authorized_by: @exemption),
          do: %Entry{position: marker.id, payload: marker.object}

    {:ok, entries}
  end

  @impl Job
  def deliver(repo, _options, entries) do
    objects =
      entries
      |> Enum.map(& &1.payload)
      |> Enum.uniq()

    with {:ok, store} <- Store.configured(),
         :ok <- Store.sync(%{store | repo: repo}, objects) do
      forget(repo, entries)
    end
  end

  defp marked(repo, rows) do
    {_written, nil} = repo.insert_all(__MODULE__, rows, authorized_by: @exemption)
    :ok
  end

  defp forget(repo, entries) do
    positions = Enum.map(entries, & &1.position)
    delivered = from(marker in __MODULE__, where: marker.id in ^positions)
    {_deleted, nil} = repo.delete_all(delivered, authorized_by: @exemption)

    :ok
  end
end
