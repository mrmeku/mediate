alias Ecto.Adapters.SQL.Sandbox
alias Mediate.OpenFGA.TestMigrations
alias Mediate.Relay.TestTables
alias Mediate.TestRepos.Sandboxed

# The outbox table and the relay's cursor table in both tiers of the
# cluster. The migration helpers create them through a deployment's kind
# of migration. The fixture's tables beside them, which the conformance
# kit writes worlds into. And the two tables the relay's test job works
# over. The durable tier is where two connections contend for one runner's
# lock, so its pool holds more than one. One server for the run, with the
# in-memory datastore, and a store per test inside it.
Mediate.Dev.Cluster.start(
  otp_app: :mediate,
  repos: [
    {Sandboxed, role: :app, database: :sandboxed, pool: Sandbox},
    {Mediate.TestRepos.Durable, role: :app, database: :durable, pool_size: 4},
    {Mediate.TestRepos.Owner, role: :owner, database: :durable, pool_size: 2}
  ],
  migrate: fn repo ->
    Mediate.Fixture.Tables.create!(repo)
    TestTables.create!(repo)
    _versions = Ecto.Migrator.run(repo, [{1, TestMigrations.Outbox}], :up, all: true, log: false)
    :ok
  end
)

_shared = Mediate.Dev.OpenFGA.start()

Sandbox.mode(Sandboxed, :manual)
ExUnit.start()
