defmodule Mix.Tasks.Mediate.Dump do
  @shortdoc "Dumps the schema the application's migrations produce into the structure file"
  @moduledoc """
  Runs the application's migrations on a cluster of its own as the owner
  role and writes `pg_dump --schema-only` to the structure file.

      mix mediate.dump && git diff --exit-code priv/repo/structure.sql

  The task reads its options from the `:mediate` key of the application's
  `mix.exs` project configuration:

      mediate: [
        dump: [
          repo: ExampleRbac.OwnerRepo,
          file: "priv/repo/structure.sql",
          migrations: "priv/repo/migrations"
        ]
      ]

  `migrations` defaults to `priv/repo/migrations`. The task puts the repo's
  configuration in the env of the repo's own `otp_app`. That application can
  be another one, when a deployment dumps the schema of a library
  application's repo. The task takes no arguments.
  """

  use Boundary, top_level?: true, deps: [Mix, Mediate.Dev.Structure]
  use Mix.Task

  alias Mediate.Dev.Structure

  @requirements ["app.config"]

  @impl Mix.Task
  def run([]) do
    {:ok, _started} = Application.ensure_all_started(:ecto_sql)
    config = Mix.Project.config()
    options = Keyword.get(config[:mediate] || [], :dump, [])
    path = Structure.dump(options)
    Mix.shell().info("wrote #{path}")
  end

  def run(_args), do: Mix.raise("mix mediate.dump takes no arguments")
end
