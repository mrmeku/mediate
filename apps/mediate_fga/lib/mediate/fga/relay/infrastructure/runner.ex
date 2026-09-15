defmodule Mediate.Fga.Relay.Infrastructure.Runner do
  # The worker: one process per runner, a timer, and the wake-up.
  #
  # It holds no state a caller needs and answers no call. Each tick runs
  # one pass and asks the arithmetic in `Mediate.Fga.Relay.Domain.Backoff`
  # when the next one is due. That is at once where a batch was full, and
  # after the idle interval where it was not. After a failure it is a wait
  # that grows.
  #
  # A wake-up is a cast, so a delivery holds up no process that wrote the
  # rows. The wake-up cancels the timer and passes at once. While a pass is
  # due the runner carries no timer, and it drops a wake-up that arrives
  # then and queues no second pass. The due pass reads everything committed
  # before it runs, which is everything a wake-up that arrives now is
  # about. The runner handles a wake-up that arrives during a pass after
  # it, where it sets a timer again. So the rows that landed mid-pass go
  # out at once and not at the next tick.
  #
  # The process registers under the runner's name unless the options say
  # otherwise. So `Mediate.Fga.Relay.wake/1` takes that name, and a test
  # starts one unregistered and wakes it by pid.
  @moduledoc false

  use GenServer

  alias Mediate.Fga.Relay.Domain.Backoff
  alias Mediate.Fga.Relay.Infrastructure.Drain
  alias Mediate.Fga.Relay.Options

  @enforce_keys [:options, :failures, :timer]
  defstruct @enforce_keys

  @type t :: %__MODULE__{options: keyword(), failures: non_neg_integer(), timer: reference() | nil}

  @doc "One child per runner, under the runner's name as its id."
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(options) when is_list(options) do
    %{id: {__MODULE__, options[:name]}, start: {__MODULE__, :start_link, [options]}}
  end

  @doc "Starts a runner. Options: `Mediate.Fga.Relay.options_schema/0`."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    options = Options.validate!(options)
    GenServer.start_link(__MODULE__, options, registration(options))
  end

  @doc "Asks a runner to pass now. Answers without a wait for the pass."
  @spec wake(GenServer.server()) :: :ok
  def wake(runner), do: GenServer.cast(runner, :wake)

  @impl GenServer
  def init(options) do
    {:ok, %__MODULE__{options: options, failures: 0, timer: nil}, {:continue, :first}}
  end

  @impl GenServer
  def handle_continue(:first, %__MODULE__{} = state) do
    {:noreply, scheduled(state, state.options[:first] || state.options[:idle])}
  end

  @impl GenServer
  def handle_cast(:wake, %__MODULE__{timer: nil} = state), do: {:noreply, state}

  def handle_cast(:wake, %__MODULE__{} = state) do
    _left = Process.cancel_timer(state.timer)
    send(self(), :pass)

    {:noreply, %{state | timer: nil}}
  end

  @impl GenServer
  def handle_info(:pass, %__MODULE__{} = state) do
    result = Drain.once(state.options)
    wait = Backoff.wait(result, state.failures, state.options)
    state = %{state | failures: Backoff.failures(result, state.failures)}

    {:noreply, scheduled(state, wait)}
  end

  defp scheduled(%__MODULE__{} = state, wait), do: %{state | timer: Process.send_after(self(), :pass, wait)}

  defp registration(options), do: if(options[:register], do: [name: options[:name]], else: [])
end
