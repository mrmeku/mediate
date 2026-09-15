defmodule Mediate.Dev.SchemaDump do
  @moduledoc """
  The mechanism behind `mix mediate.schema_dump`. It starts an ephemeral
  cluster, runs the caller's migrations as the owner role, writes
  `pg_dump --schema-only` to a file, and stops the cluster. The file is the
  teaching artifact a thin application commits under `priv/schema/`.
  `git diff --exit-code` on that file proves the migrations produce the
  schema the repository shows.

  `pg_dump` 18 opens and closes its output with `\\restrict` and
  `\\unrestrict` lines that carry a random token. The dump removes them, so
  the file is the same on every run.
  """

  use Boundary, top_level?: true, deps: [Ecto.Migrator, NimbleOptions, Mediate.Dev.Cluster]

  alias Mediate.Dev.Cluster

  @schema NimbleOptions.new!(
            otp_app: [
              type: :atom,
              doc: "The application whose env receives the repo's config. The repo's own `otp_app` when absent."
            ],
            repo: [type: :atom, required: true, doc: "An owner-role repo module of the application."],
            output: [type: :string, required: true, doc: "The file to write, such as `priv/schema/rbac.sql`."],
            migrations: [
              type: {:or, [:string, {:list, {:tuple, [:integer, :atom]}}]},
              default: "priv/repo/migrations",
              doc: "A migrations directory, or `{version, module}` pairs."
            ]
          )

  @doc "Runs the dump. Returns the path it wrote. Options: #{NimbleOptions.docs(@schema)}"
  @spec dump(keyword()) :: Path.t()
  def dump(options) when is_list(options) do
    options = NimbleOptions.validate!(options, @schema)
    migrations = loaded(options[:migrations])

    cluster =
      Cluster.start(
        otp_app: options[:otp_app] || options[:repo].config()[:otp_app],
        repos: [{options[:repo], role: :owner, database: :sandboxed, pool_size: 2}],
        migrate: &migrate!(&1, migrations)
      )

    try do
      write!(options[:output], schema_sql(cluster))
    after
      Cluster.stop(cluster)
    end

    options[:output]
  end

  defp migrate!(repo, migrations) do
    _versions = Ecto.Migrator.run(repo, migrations, :up, all: true, log: false)
    :ok
  end

  # The files of a directory, loaded once. The cluster migrates each of its
  # databases, and a load per database redefines the modules.
  defp loaded(pairs) when is_list(pairs), do: pairs

  defp loaded(directory) when is_binary(directory) do
    directory
    |> Path.join("*.exs")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&loaded_file/1)
  end

  defp loaded_file(file) do
    {version, _name} = Integer.parse(Path.basename(file))
    [{module, _binary} | _rest] = Code.require_file(file) || Code.compile_file(file)
    {version, module}
  end

  defp schema_sql(%Cluster{} = cluster) do
    args = ["--schema-only", "-h", cluster.socket_dir, "-U", Cluster.role(:owner), Cluster.database(:sandboxed)]

    case System.cmd("pg_dump", args, stderr_to_stdout: true, env: [{"PGPASSWORD", nil}, {"PGOPTIONS", nil}]) do
      {output, 0} -> strip_restrict(output)
      {output, status} -> raise "pg_dump exited with #{status}: #{output}"
    end
  end

  defp strip_restrict(sql) do
    sql
    |> String.split("\n")
    |> Enum.reject(&String.starts_with?(&1, ["\\restrict ", "\\unrestrict "]))
    |> Enum.join("\n")
  end

  defp write!(path, sql) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, sql)
  end
end
