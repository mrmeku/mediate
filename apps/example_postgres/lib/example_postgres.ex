defmodule ExamplePostgres do
  @moduledoc """
  The example bound to row-level security. Nothing of the domain lives here.

  The package holds three things:

  - `ExamplePostgres.Infrastructure.Policies`, the SQL that states the
    example's rules as Postgres policies
  - the migrations, which reassign the protected tables to the owner role
    and write those policies
  - `ExamplePostgres.Application`, the boot that binds the example's schemas
    to `Example.Infrastructure.Repo`

  `Mediate.Postgres.Version` says what a policy version is. The rules
  migration publishes one from the policies it wrote, and `publish/0`
  publishes the same version from the loaded catalog at boot.
  """

  use Boundary,
    deps: [Example, Mediate, Mediate.Postgres, Ecto],
    exports: [Application, Infrastructure.Policies]

  alias Mediate.Config
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Version

  @author "example_postgres"
  @approval "the migration under review"
  @content_bytes 65_536

  @doc "Who wrote the rules, as the record of a policy version carries it."
  @spec author() :: String.t()
  def author, do: @author

  @doc "What approved them, as the record of a policy version carries it."
  @spec approval() :: String.t()
  def approval, do: @approval

  @doc """
  Emits the version the database is at, from the policies the loaded catalog
  holds.
  """
  @spec publish() :: {:ok, Mediate.PolicyVersion.t()}
  def publish do
    %Catalog{} = catalog = Mediate.Postgres.load!()
    {:ok, config} = Config.resolve()
    fields = [at: config.clock.()] ++ published(catalog.version)

    Version.publish(Version.of(Mediate.Postgres, catalog.policies, fields))
  end

  @doc """
  The fields a published version carries beside its policies and its moment.
  The caller supplies the moment. The boot supplies the configured clock. The
  rules migration takes the default of `Mediate.Postgres.Migration.publish!/2`,
  because it publishes before there is a configuration to read.
  """
  @spec published(String.t()) :: keyword()
  def published(version) when is_binary(version) do
    [
      version: version,
      author: @author,
      approval: @approval,
      content_bytes: @content_bytes
    ]
  end
end
