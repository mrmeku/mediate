defmodule Mediate.Dev.OpenFGA do
  @moduledoc """
  One OpenFGA server per test run, and one of its own for a test that
  needs a server it can throw away.

  `start/1` starts `openfga run` under `MuonTrap.Daemon`. The daemon kills
  the operating-system process when the Erlang process that owns it dies
  and when the virtual machine exits. So no server outlives the run that
  started it.

  The datastore is the in-memory one. So a run leaves nothing on disk, and
  the next run starts empty. The store isolates one test from another, and
  each test creates its own. `test/test_helper.exs` calls `start/1` once
  for the run, and a second call returns the run's server.

  `start_supervised!/1` is a server of one test's own, through the
  supervisor of `ExUnit`, for a test whose tuples belong to no other test.
  It stops when that test ends and takes them with it.

  Both listen on free ports of the loopback interface. Both wait for the
  health endpoint to answer before they return. So a caller that gets a
  struct back has a server that answers.

  The playground and the metrics listener are off. They bind ports of their
  own, and a second server on the same machine collides on them. Nothing
  here speaks the model language or the decision API. The engine package
  does that.
  """

  use Boundary, top_level?: true, deps: [MuonTrap, NimbleOptions, Mediate.Dev]

  @schema NimbleOptions.new!(
            dir: [
              type: :string,
              doc: "The working directory of the server process. A directory under `tmp/` by default."
            ],
            timeout: [
              type: :pos_integer,
              default: 20_000,
              doc: "How long to wait for the health endpoint, in milliseconds."
            ]
          )

  @enforce_keys [:http, :grpc, :dir]
  defstruct [:http, :grpc, :dir, :daemon]

  @typedoc "A running OpenFGA server."
  @type t :: %__MODULE__{
          http: String.t(),
          grpc: String.t(),
          dir: Path.t(),
          daemon: pid() | nil
        }

  @doc "The schema of the options both starts take: #{NimbleOptions.docs(@schema)}"
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @schema

  @doc "The run's server, started on the first call and returned on every call after it."
  @spec start(keyword()) :: t()
  def start(options \\ []) when is_list(options) do
    case :persistent_term.get(__MODULE__, nil) do
      %__MODULE__{} = current ->
        current

      nil ->
        server = prepare(options)
        daemon = start_daemon!(server)
        current = await!(%{server | daemon: daemon}, timeout(options))
        :persistent_term.put(__MODULE__, current)
        stop_with_suite()
        current
    end
  end

  @doc "A server of the current test's own. It stops when the test ends."
  @spec start_supervised!(keyword()) :: t()
  def start_supervised!(options \\ []) when is_list(options) do
    server = prepare(options)
    daemon = ExUnit.Callbacks.start_supervised!(child_spec(server))
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(server.dir) end)
    await!(%{server | daemon: daemon}, timeout(options))
  end

  @doc "The run's server, for a test that reads its addresses. Raises when none was started."
  @spec current!() :: t()
  def current! do
    case :persistent_term.get(__MODULE__, nil) do
      %__MODULE__{} = current ->
        current

      nil ->
        raise "no OpenFGA server was started for this run. " <>
                "Call Mediate.Dev.OpenFGA.start/1 in test/test_helper.exs " <>
                "or Mediate.Dev.OpenFGA.start_supervised!/1 in the test."
    end
  end

  @doc """
  The child specification of the server's daemon, the options this module
  gives `MuonTrap.Daemon` for an `openfga run`.
  """
  @spec child_spec(t()) :: Supervisor.child_spec()
  def child_spec(%__MODULE__{} = server) do
    Supervisor.child_spec(
      {MuonTrap.Daemon, ["openfga", arguments(server), daemon_options(server)]},
      id: {__MODULE__, server.http}
    )
  end

  @doc "Stops the server and removes its directory. Safe to call twice."
  @spec stop(t()) :: :ok
  def stop(%__MODULE__{} = server) do
    if is_pid(server.daemon) and Process.alive?(server.daemon), do: GenServer.stop(server.daemon)
    File.rm_rf!(server.dir)
    if :persistent_term.get(__MODULE__, nil) == server, do: :persistent_term.erase(__MODULE__)
    :ok
  end

  @doc "Stops the run's server. Registered with `ExUnit.after_suite/1` and `System.at_exit/1`."
  @spec stop_all(term()) :: :ok
  def stop_all(_status) do
    case :persistent_term.get(__MODULE__, nil) do
      %__MODULE__{} = current -> stop(current)
      nil -> :ok
    end
  end

  @doc "Whether the server at an HTTP address answers its health endpoint."
  @spec healthy?(String.t()) :: boolean()
  def healthy?(http) when is_binary(http) do
    request = {~c"http://#{http}/healthz", []}

    case :httpc.request(:get, request, [timeout: 1_000, connect_timeout: 1_000], body_format: :binary) do
      {:ok, {{_version, 200, _reason}, _headers, body}} -> body =~ "SERVING"
      _unhealthy -> false
    end
  end

  # A free port of the loopback interface. The operating system names one
  # for a listener that asks for port zero, and the server takes it after
  # the listener closes. Two runs on one machine never meet, because each
  # asks.
  @spec free_port() :: pos_integer()
  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, reuseaddr: true)
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end

  defp prepare(options) do
    options = NimbleOptions.validate!(options, @schema)
    dir = options[:dir] || Path.join([File.cwd!(), "tmp", "openfga-" <> suffix()])

    server = %__MODULE__{
      http: "127.0.0.1:#{free_port()}",
      grpc: "127.0.0.1:#{free_port()}",
      dir: dir
    }

    File.mkdir_p!(dir)
    server
  end

  # The datastore is in memory, so the addresses are the only configuration.
  # The playground and the metrics listener bind ports this module did not
  # ask for. A second server on the same machine collides on them.
  defp arguments(%__MODULE__{} = server) do
    [
      "run",
      "--datastore-engine",
      "memory",
      "--http-addr",
      server.http,
      "--grpc-addr",
      server.grpc,
      "--playground-enabled=false",
      "--metrics-enabled=false",
      "--log-level=error"
    ]
  end

  # The environment of the shell that runs the tests must not redirect the
  # server to another datastore or another address.
  defp daemon_options(%__MODULE__{} = server) do
    cleared =
      ~w(OPENFGA_DATASTORE_ENGINE OPENFGA_DATASTORE_URI OPENFGA_HTTP_ADDR OPENFGA_GRPC_ADDR
         OPENFGA_PLAYGROUND_ENABLED OPENFGA_METRICS_ENABLED OPENFGA_AUTHN_METHOD OPENFGA_LOG_LEVEL)

    [
      cd: server.dir,
      env: Enum.map(cleared, &{&1, nil}),
      stderr_to_stdout: true,
      log_output: :debug,
      log_prefix: "openfga: "
    ]
  end

  defp start_daemon!(%__MODULE__{} = server) do
    %{start: {module, function, arguments}} = child_spec(server)
    {:ok, daemon} = apply(module, function, arguments)
    daemon
  end

  defp await!(%__MODULE__{} = server, timeout) do
    Mediate.Dev.poll!(fn -> healthy?(server.http) end, timeout)
    server
  end

  defp timeout(options), do: Keyword.get(options, :timeout, @schema.schema[:timeout][:default])

  defp suffix, do: Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)

  # Registered once per virtual machine. Remote captures, not closures.
  # Coverage recompiles this module, and a closure from the old code is
  # invalid by the time the callbacks run.
  defp stop_with_suite do
    if !:persistent_term.get({__MODULE__, :callbacks}, false) do
      _loaded = Application.load(:ex_unit)
      ExUnit.after_suite(&__MODULE__.stop_all/1)
      System.at_exit(&__MODULE__.stop_all/1)
      :persistent_term.put({__MODULE__, :callbacks}, true)
    end
  end
end
