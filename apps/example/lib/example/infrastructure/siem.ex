defmodule Example.Infrastructure.SIEM do
  @moduledoc """
  The example's consumer of the library's three events. It is a process
  that maps every decision, identity write, and resource read event to an
  OCSF record and holds the result in memory: the security log.

  A deployment sends those records to its own security log. A list keeps
  the mapping under test and puts no schema version in a published
  package. The mapping lives in the OCSF module beside this one, against
  OCSF 1.3.0, and `ocsf_version/0` answers that version. It answers from
  the payload alone. What OCSF names no field for travels under
  `unmapped`. A decision event whose call raised, one with `effect: nil`,
  is dropped, because it is no decision.

  Records arrive as casts, and a caller reads them with calls. So a caller
  that caused an event reads its own records afterwards. A deployment
  starts one at boot. A test starts its own, unattached, and feeds it
  payloads.
  """

  use GenServer

  alias Example.Infrastructure.OCSF
  alias Mediate.IdentityWrite
  alias Mediate.ResourceRead

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
  @spec ocsf_version() :: String.t()
  defdelegate ocsf_version, to: OCSF, as: :version

  @doc "Every record it holds, oldest first."
  @spec records(GenServer.server()) :: [map()]
  def records(siem), do: GenServer.call(siem, :records)

  @doc "The records of one correlation id, oldest first."
  @spec records(GenServer.server(), String.t()) :: [map()]
  def records(siem, correlation_id) when is_binary(correlation_id) do
    siem
    |> records()
    |> Enum.filter(&(&1.metadata.correlation_uid == correlation_id))
  end

  @doc false
  @spec handle_event([atom()], map(), map(), GenServer.server()) :: :ok
  def handle_event([:mediate, :identity, :write], _measurements, payload, siem) do
    record(siem, OCSF.identity_write(payload))
  end

  def handle_event([:mediate, :resource, :read], _measurements, payload, siem) do
    record(siem, OCSF.resource_read(payload))
  end

  def handle_event([:mediate, :decision], _measurements, %{effect: nil}, _siem), do: :ok

  def handle_event([:mediate, :decision], %{duration_microseconds: duration}, payload, siem) do
    record(siem, OCSF.decision(payload, duration))
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

  defp events, do: [Mediate.event(), IdentityWrite.event(), ResourceRead.event()]

  defp record(siem, record) when is_map(record), do: GenServer.cast(siem, {:record, record})

  defp handler_id, do: {__MODULE__, self()}
end
