defmodule Mix.Tasks.Mediate.SchemaDump do
  @shortdoc "Dumps the schema the application's migrations produce into a committed file"
  @moduledoc """
  Runs the application's migrations on an ephemeral cluster as the owner
  role and writes `pg_dump --schema-only` to the configured file.

      mix mediate.schema_dump && git diff --exit-code priv/schema/

  The task reads its options from the `:mediate` key of the application's
  `mix.exs` project configuration:

      mediate: [
        schema_dump: [
          repo: ExampleRbac.OwnerRepo,
          output: "priv/schema/rbac.sql",
          migrations: "priv/repo/migrations"
        ]
      ]

  `migrations` defaults to `priv/repo/migrations`. The task puts the repo's
  configuration in the env of the repo's own `otp_app`. That application can
  be another one, when a thin application dumps the schema of a library
  application's repo. The task takes no arguments.
  """

  use Boundary, top_level?: true, deps: [Mix, Mediate.Dev.SchemaDump]
  use Mix.Task

  alias Mediate.Dev.SchemaDump

  @requirements ["app.config"]

  @impl Mix.Task
  def run([]) do
    {:ok, _started} = Application.ensure_all_started(:ecto_sql)
    config = Mix.Project.config()
    options = Keyword.get(config[:mediate] || [], :schema_dump, [])
    path = SchemaDump.dump(options)
    Mix.shell().info("wrote #{path}")
  end

  def run(_args), do: Mix.raise("mix mediate.schema_dump takes no arguments")
end
