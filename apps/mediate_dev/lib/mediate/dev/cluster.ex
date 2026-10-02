defmodule Mediate.Dev.Cluster do
  @moduledoc """
  One Postgres cluster per `mix test` run, and one per structure dump.

  `start/1` takes about one second and does these steps in order:

  1. `initdb` into `tmp/pg-<random>/data` with `--auth=trust`.
  2. `pg_ctl start` on a unix socket alone, with no TCP port and
     `fsync=off`.
  3. Create the roles: `mediate_owner`, the owner role, which owns every
     table and runs the migrations, and `mediate_app`, the app role, which
     the application connects as and which carries `NOBYPASSRLS`.
  4. Create the databases: `mediate_sandboxed`, the sandboxed database,
     where every test runs in a transaction that rolls back, and
     `mediate_durable`, the durable database, which keeps what a test
     commits.
  5. Run the caller's `migrate:` function once per database, as the owner.
  6. Put each repo's config in the application env. This is the one place
     in a test run that calls `Application.put_env`, and it runs before any
     repo starts.
  7. Start the caller's repos, and register `stop_all/1` with
     `ExUnit.after_suite/1` and `System.at_exit/1`. The cluster stops and
     its directory goes away when the suite ends, or at VM exit for a run
     that is no suite.

  So a VM that runs several suites in turn, the umbrella root's
  `mix test`, starts each app's cluster afresh. Everything here goes
  through `psql`, `initdb`, and `pg_ctl`. So this module needs `ecto` and
  nothing from `ecto_sql`, and the sandbox mode is the caller's to set.
  """

  use Boundary, top_level?: true, deps: [NimbleOptions]

  @owner "mediate_owner"
  @app "mediate_app"
  @databases [sandboxed: "mediate_sandboxed", durable: "mediate_durable"]
  @initdb_user "postgres"

  # The host's libpq environment must not redirect any tool to another server.
  @cmd_opts [
    stderr_to_stdout: true,
    env: Enum.map(~w(PGHOST PGHOSTADDR PGPORT PGUSER PGPASSWORD PGDATABASE PGSERVICE PGOPTIONS PGSSLMODE), &{&1, nil})
  ]

  @repo_schema NimbleOptions.new!(
                 role: [type: {:in, [:app, :owner]}, required: true, doc: "Which role the repo connects as."],
                 database: [
                   type: {:in, [:sandboxed, :durable]},
                   required: true,
                   doc: "Which database the repo connects to."
                 ],
                 pool: [type: :atom, doc: "A pool module to put in the repo's config, such as the SQL sandbox."],
                 pool_size: [type: :pos_integer, default: 10]
               )

  @schema NimbleOptions.new!(
            otp_app: [type: :atom, required: true, doc: "The application whose env receives each repo's config."],
            repos: [
              type: {:list, {:custom, __MODULE__, :validate_repo, []}},
              required: true,
              doc: "`{RepoModule, role: :app | :owner, database: :sandboxed | :durable}` per repo to start."
            ],
            migrate: [
              type: {:fun, 1},
              required: true,
              doc: "Called once per database with an owner-role repo whose dynamic instance points at that database."
            ]
          )

  @enforce_keys [:dir, :socket_dir, :data_dir, :log_file, :repos]
  defstruct [:supervisor | @enforce_keys]

  @type t :: %__MODULE__{
          dir: Path.t(),
          socket_dir: Path.t(),
          data_dir: Path.t(),
          log_file: Path.t(),
          repos: [module()],
          supervisor: pid() | nil
        }

  @type database :: :sandboxed | :durable
  @type role :: :app | :owner

  @doc "Starts the cluster and the repos. Raises on any failure. Options: #{NimbleOptions.docs(@schema)}"
  @spec start(keyword()) :: t()
  def start(opts) when is_list(opts) do
    opts = NimbleOptions.validate!(opts, @schema)
    cluster = new(opts)
    File.mkdir_p!(cluster.dir)
    stop_with_suite()
    initdb!(cluster)
    pg_ctl!(cluster, ["start"])
    create_roles_and_databases!(cluster)
    Enum.each(@databases, fn {_database, name} -> migrate!(cluster, opts, name) end)
    configure_repos!(cluster, opts)
    cluster = %{cluster | supervisor: start_repos!(opts)}
    :persistent_term.put(__MODULE__, [cluster | registered()])
    cluster
  end

  @doc "Stops the cluster and removes its directory. Safe to call twice."
  @spec stop(t()) :: :ok
  def stop(%__MODULE__{} = cluster) do
    if is_pid(cluster.supervisor) and Process.alive?(cluster.supervisor), do: Supervisor.stop(cluster.supervisor)
    {_output, _status} = System.cmd("pg_ctl", ["-D", cluster.data_dir, "-m", "immediate", "stop"], @cmd_opts)
    File.rm_rf!(cluster.dir)
    :persistent_term.put(__MODULE__, List.delete(registered(), cluster))
    :ok
  end

  @doc "Stops every cluster this VM started. Registered with `System.at_exit/1`."
  @spec stop_all(term()) :: :ok
  def stop_all(_status), do: Enum.each(registered(), &stop/1)

  @doc "The cluster started last, for a test that inspects it."
  @spec current() :: t()
  def current, do: hd(registered())

  @doc "The Postgres name of a database."
  @spec database_name(database()) :: String.t()
  def database_name(database) when database in [:sandboxed, :durable], do: Keyword.fetch!(@databases, database)

  @doc "The Postgres name of a role."
  @spec role_name(role()) :: String.t()
  def role_name(:app), do: @app
  def role_name(:owner), do: @owner

  @doc "The config a repo starts with for a role and a database, as Postgrex and Ecto accept it."
  @spec config(t(), role(), database()) :: keyword()
  def config(%__MODULE__{} = cluster, role, database)
      when role in [:app, :owner] and database in [:sandboxed, :durable] do
    [socket_dir: cluster.socket_dir, username: role_name(role), database: database_name(database)]
  end

  @doc "Runs a SQL statement through `psql` as the superuser. Raises on failure."
  @spec psql!(t(), String.t(), String.t()) :: String.t()
  def psql!(%__MODULE__{} = cluster, database, statement) when is_binary(database) and is_binary(statement) do
    run!(
      "psql",
      ["-h", cluster.socket_dir, "-U", @initdb_user, "-d", database, "-v", "ON_ERROR_STOP=1", "-Atc", statement],
      cluster
    )
  end

  @doc false
  @spec validate_repo(term()) :: {:ok, {module(), keyword()}} | {:error, String.t()}
  def validate_repo({repo, config}) when is_atom(repo) and is_list(config) do
    case NimbleOptions.validate(config, @repo_schema) do
      {:ok, config} -> {:ok, {repo, config}}
      {:error, error} -> {:error, "#{inspect(repo)}: #{Exception.message(error)}"}
    end
  end

  def validate_repo(other), do: {:error, "expected {RepoModule, keyword}, got: #{inspect(other)}"}

  defp random_suffix do
    Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)
  end

  defp initdb!(cluster) do
    run!(
      "initdb",
      ["-D", cluster.data_dir, "--auth=trust", "--username=#{@initdb_user}", "--no-sync", "-E", "UTF8", "--no-locale"],
      cluster
    )
  end

  # No TCP listener, only the socket in the cluster directory. Durability is
  # off, because the cluster lives for one test run and then goes away.
  defp pg_ctl!(cluster, args) do
    server_options =
      Enum.join(
        [
          "-k #{cluster.socket_dir}",
          "-c listen_addresses=''",
          "-c fsync=off",
          "-c synchronous_commit=off",
          "-c full_page_writes=off",
          "-c log_min_messages=warning"
        ],
        " "
      )

    run!("pg_ctl", ["-D", cluster.data_dir, "-l", cluster.log_file, "-w", "-o", server_options] ++ args, cluster)
  end

  defp run!(program, args, cluster) do
    case System.cmd(program, args, @cmd_opts) do
      {output, 0} ->
        output

      {output, status} ->
        log = if File.exists?(cluster.log_file), do: File.read!(cluster.log_file), else: ""
        raise "#{program} #{Enum.join(args, " ")} exited #{status}:\n#{output}\n#{log}"
    end
  end

  defp create_roles_and_databases!(cluster) do
    statements =
      ["CREATE ROLE #{@owner} LOGIN", "CREATE ROLE #{@app} LOGIN NOBYPASSRLS"] ++
        Enum.map(@databases, fn {_database, name} -> "CREATE DATABASE #{name} OWNER #{@owner}" end)

    Enum.each(statements, &psql!(cluster, "postgres", &1))
  end

  # Migrations run through the first owner-role repo, pointed at each database
  # in turn with a dynamic instance. The repo's static instance starts later.
  defp migrate!(cluster, opts, name) do
    case Enum.find(opts[:repos], fn {_repo, config} -> config[:role] == :owner end) do
      nil -> :ok
      {repo, _config} -> on(cluster, repo, :owner, name, fn _pid -> :ok = opts[:migrate].(repo) end)
    end
  end

  # A dynamic instance of the repo on one database, in force on this process
  # for the length of the function and stopped after it.
  defp on(cluster, repo, role, name, fun) do
    config = [socket_dir: cluster.socket_dir, username: role_name(role), database: name]
    {:ok, pid} = repo.start_link([name: nil, pool_size: 2] ++ config)
    previous = repo.put_dynamic_repo(pid)

    try do
      fun.(pid)
    after
      repo.put_dynamic_repo(previous)
      Supervisor.stop(pid)
    end
  end

  # Repo config lands in the application env before any repo starts. That
  # is the one place that can call `Application.put_env`: boot, not a test.
  defp configure_repos!(cluster, opts) do
    Enum.each(opts[:repos], fn {repo, repo_config} ->
      pool = if repo_config[:pool], do: [pool: repo_config[:pool]], else: []

      Application.put_env(
        opts[:otp_app],
        repo,
        config(cluster, repo_config[:role], repo_config[:database]) ++ [pool_size: repo_config[:pool_size]] ++ pool
      )
    end)
  end

  defp new(opts) do
    dir = Path.join([File.cwd!(), "tmp", "pg-" <> random_suffix()])

    %__MODULE__{
      dir: dir,
      socket_dir: dir,
      data_dir: Path.join(dir, "data"),
      log_file: Path.join(dir, "postgres.log"),
      repos: Enum.map(opts[:repos], &elem(&1, 0))
    }
  end

  defp registered, do: :persistent_term.get(__MODULE__, [])

  # Registered once per VM. Remote captures, not closures. Coverage
  # recompiles this module, and a closure from the old code is invalid by
  # the time the callbacks run.
  defp stop_with_suite do
    if !:persistent_term.get({__MODULE__, :callbacks}, false) do
      _loaded = Application.load(:ex_unit)
      ExUnit.after_suite(&__MODULE__.stop_all/1)
      System.at_exit(&__MODULE__.stop_all/1)
      :persistent_term.put({__MODULE__, :callbacks}, true)
    end
  end

  # Unnamed, so a structure dump can start its own cluster inside a test run.
  defp start_repos!(opts) do
    children = Enum.map(opts[:repos], fn {repo, _config} -> repo end)
    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one)
    pid
  end
end
