alias Ecto.Adapters.SQL.Sandbox
alias Example.Infrastructure.Repo

# The migration files load once, here and not in `migrate:`, which the
# cluster calls once per database. The list also goes into the application
# environment, where a test can read it without a second load.
migrations =
  for file <- Enum.sort(Path.wildcard("priv/repo/migrations/*.exs")) do
    [{module, _binary}] = Code.require_file(file)
    {version, _name} = Integer.parse(Path.basename(file))
    {version, module}
  end

:ok = Application.put_env(:example_postgres, :migrations, migrations)

# Both repos point at one database, because the committed scenarios write
# through the app repo and truncate through the owner repo. The `otp_app` is
# the example's, because the repo modules read their configuration there.
Mediate.Dev.Cluster.start(
  otp_app: :example,
  repos: [
    {Repo, role: :app, database: :sandboxed, pool: Sandbox},
    {Example.Infrastructure.OwnerRepo, role: :owner, database: :sandboxed, pool_size: 2}
  ],
  migrate: fn repo ->
    [_domain, _rules] = Ecto.Migrator.run(repo, migrations, :up, all: true, log: false)
    :ok
  end
)

# The application leaves the catalog read and the publish to whoever starts
# the repos, and here the cluster does. The catalog is a query, so the read
# waits for the repos.
_catalog = Mediate.Postgres.load!()
{:ok, _published} = ExamplePostgres.publish()

Sandbox.mode(Repo, :manual)

ExUnit.start()
