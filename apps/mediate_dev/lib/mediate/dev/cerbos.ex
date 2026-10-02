defmodule Mediate.Dev.Cerbos do
  @moduledoc """
  One Cerbos server per test run, and one of its own for a test that
  changes what the run's server must not change.

  `start/1` writes a configuration file and starts `cerbos server` under
  `MuonTrap.Daemon`. The daemon kills the operating-system process when the
  Erlang process that owns it dies and when the virtual machine exits. So no
  server outlives the run that started it.

  The server reads the policy directory the caller names. It listens on a
  free port of the loopback interface, and the caller puts that address in
  the engine's configuration entry. `test/test_helper.exs` calls `start/1`
  once for the run, and a second call returns the run's server.

  `start_supervised!/1` is the same server owned by one test, through the
  supervisor of `ExUnit`. A test that releases a policy version needs it,
  because such a test writes into a policy directory the run's other tests
  read at the same time. It stops when the test ends.

  Both wait for the health endpoint to answer before they return. So a
  caller that gets a struct back has a server that answers. Nothing here
  speaks the policy language or the decision API. The engine package does
  that.
  """

  use Boundary, top_level?: true, deps: [MuonTrap, NimbleOptions, Mediate.Dev]

  @schema NimbleOptions.new!(
            policy_dir: [
              type: :string,
              required: true,
              doc: "The directory the server reads its policies from."
            ],
            dir: [
              type: :string,
              doc: "Where the configuration file goes. A directory under `tmp/` by default."
            ],
            watch: [
              type: :boolean,
              default: true,
              doc: "Whether the server watches the policy directory, which is how a released policy reaches it."
            ],
            timeout: [
              type: :pos_integer,
              default: 20_000,
              doc: "How long to wait for the health endpoint, in milliseconds."
            ]
          )

  @enforce_keys [:http, :dir, :policy_dir, :config_file]
  defstruct [:http, :dir, :policy_dir, :config_file, :daemon]

  @typedoc "A running Cerbos server."
  @type t :: %__MODULE__{
          http: String.t(),
          dir: Path.t(),
          policy_dir: Path.t(),
          config_file: Path.t(),
          daemon: pid() | nil
        }

  @doc "The schema of the options both starts take: #{NimbleOptions.docs(@schema)}"
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @schema

  @doc "The run's server, started on the first call and returned on every call after it."
  @spec start(keyword()) :: t()
  def start(options) when is_list(options) do
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
  def start_supervised!(options) when is_list(options) do
    server = prepare(options)
    daemon = ExUnit.Callbacks.start_supervised!(child_spec(server))
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(server.dir) end)
    await!(%{server | daemon: daemon}, timeout(options))
  end

  @doc "The run's server, for a test that reads its address or its policy directory. Raises when none was started."
  @spec current!() :: t()
  def current! do
    case :persistent_term.get(__MODULE__, nil) do
      %__MODULE__{} = current ->
        current

      nil ->
        raise "no Cerbos server was started for this run. " <>
                "Call Mediate.Dev.Cerbos.start/1 in test/test_helper.exs " <>
                "or Mediate.Dev.Cerbos.start_supervised!/1 in the test."
    end
  end

  @doc """
  The child specification of the server's daemon, the options this module
  gives `MuonTrap.Daemon` for a `cerbos server`.
  """
  @spec child_spec(t()) :: Supervisor.child_spec()
  def child_spec(%__MODULE__{} = server) do
    Supervisor.child_spec(
      {MuonTrap.Daemon, ["cerbos", ["server", "--config", server.config_file], daemon_options(server)]},
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
    request = {~c"http://#{http}/_cerbos/health", []}

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
    dir = options[:dir] || Path.join([File.cwd!(), "tmp", "cerbos-" <> suffix()])
    port = free_port()

    server = %__MODULE__{
      http: "127.0.0.1:#{port}",
      dir: dir,
      policy_dir: Path.expand(options[:policy_dir]),
      config_file: Path.join(dir, "config.yaml")
    }

    File.mkdir_p!(dir)
    File.write!(server.config_file, configuration(server, port, options[:watch]))
    server
  end

  # The server's configuration: the caller's policies on disk and one
  # listener per protocol. Cerbos starts its gRPC listener whether or not
  # anyone connects to it. The audit log stays off, because nothing reads
  # what it writes.
  defp configuration(%__MODULE__{} = server, port, watch?) do
    """
    server:
      httpListenAddr: "127.0.0.1:#{port}"
      grpcListenAddr: "unix:#{Path.join(server.dir, "grpc.sock")}"
    storage:
      driver: "disk"
      disk:
        directory: "#{server.policy_dir}"
        watchForChanges: #{watch?}
    """
  end

  # The environment of the shell that runs the tests must not redirect the
  # server to another configuration or another policy store.
  defp daemon_options(%__MODULE__{} = server) do
    [
      cd: server.dir,
      env: Enum.map(~w(CERBOS_CONFIG CERBOS_HUB_DEPLOYMENT_ID CERBOS_HUB_PLAYGROUND_ID), &{&1, nil}),
      stderr_to_stdout: true,
      log_output: :debug,
      log_prefix: "cerbos: "
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
