defmodule Example.Infrastructure.Siem do
  @moduledoc """
  The example's consumer of the library's three events. It is a process
  that maps every decision, change, and access event to an OCSF record and
  holds the result in memory.

  A deployment sends those records to its security log. A list keeps the
  mapping under test and puts no schema version in a published package. The
  mapping is this package's own and answers from the payload alone.

  Records arrive as casts, and a caller reads them with calls. So a caller
  that caused an event reads its own records afterwards. The thin
  application starts one at boot. A test starts its own, unattached, and
  feeds it payloads.
  """

  use GenServer

  alias Example.Infrastructure.Ocsf
  alias Mediate.Access
  alias Mediate.Change
  alias Mediate.Port

  @schema NimbleOptions.new!(
            name: [type: :any, doc: "A registered name, or none."],
            attach: [type: :boolean, default: false, doc: "Attach to the library's three events."]
          )

  @doc "Start the consumer. Options: #{NimbleOptions.docs(@schema)}"
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) when is_list(opts) do
    opts = NimbleOptions.validate!(opts, @schema)

    case opts[:name] do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc "The OCSF schema version of its records."
  @spec schema_version() :: String.t()
  defdelegate schema_version, to: Ocsf, as: :version

  @doc "Every record it holds, oldest first."
  @spec records(GenServer.server()) :: [map()]
  def records(siem), do: GenServer.call(siem, :records)

  @doc "The records of one operation, oldest first."
  @spec records(GenServer.server(), String.t()) :: [map()]
  def records(siem, operation_id) when is_binary(operation_id) do
    siem
    |> records()
    |> Enum.filter(&(&1.metadata.correlation_uid == operation_id))
  end

  @doc false
  @spec handle_event([atom()], map(), map(), GenServer.server()) :: :ok
  def handle_event([:mediate, :change], _measurements, payload, siem) do
    record(siem, Ocsf.change(payload))
  end

  def handle_event([:mediate, :access], _measurements, payload, siem) do
    record(siem, Ocsf.access(payload))
  end

  def handle_event([:mediate, :decision], _measurements, %{verdict: nil}, _siem), do: :ok

  def handle_event([:mediate, :decision], %{duration: duration}, metadata, siem) do
    record(siem, Ocsf.decision(metadata, duration))
  end

  @impl GenServer
  def init(opts) do
    if opts[:attach] do
      Process.flag(:trap_exit, true)
      :ok = :telemetry.attach_many(handler_id(), events(), &__MODULE__.handle_event/4, self())
    end

    {:ok, %{records: [], attached: opts[:attach]}}
  end

  @impl GenServer
  def handle_cast({:record, record}, state), do: {:noreply, %{state | records: [record | state.records]}}

  @impl GenServer
  def handle_call(:records, _from, state), do: {:reply, Enum.reverse(state.records), state}

  @impl GenServer
  def terminate(_reason, %{attached: true}), do: :telemetry.detach(handler_id())
  def terminate(_reason, _state), do: :ok

  defp events, do: [Port.event(), Change.event(), Access.event()]

  defp record(siem, record) when is_map(record), do: GenServer.cast(siem, {:record, record})

  defp handler_id, do: {__MODULE__, self()}
end
