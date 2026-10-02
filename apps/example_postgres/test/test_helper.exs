alias Ecto.Adapters.SQL.Sandbox
alias Example.Infrastructure.Repo

# The migration files load once, here and not in `migrate:`, which the
# cluster calls once per database.
migrations =
  for file <- Enum.sort(Path.wildcard("priv/repo/migrations/*.exs")) do
    [{module, _binary}] = Code.require_file(file)
    {version, _name} = Integer.parse(Path.basename(file))
    {version, module}
  end

# Both repos point at one database, because the durable scenarios write
# through the app repo and truncate through the owner repo. The `otp_app` is
# the example's, because the repo modules read their configuration there.
Mediate.Dev.Cluster.start(
  otp_app: :example,
  repos: [
    {Repo, role: :app, database: :sandboxed, pool: Sandbox},
    {Example.Infrastructure.OwnerRepo, role: :owner, database: :sandboxed, pool_size: 2}
  ],
  migrate: fn repo ->
    [_domain, _policy] = Ecto.Migrator.run(repo, migrations, :up, all: true, log: false)
    :ok
  end
)

# The application leaves the catalog load to whoever starts the repos, and
# here the cluster does. The catalog is a query, so the load waits for the
# repos.
_catalog = Mediate.Postgres.load_catalog!()

Sandbox.mode(Repo, :manual)

ExUnit.start()
