alias Ecto.Adapters.SQL.Sandbox
alias Mediate.Postgres.Conformance.Rules
alias Mediate.TestRepos.Sandboxed

# The owner role creates the fixture's tables. Then the conformance
# migration protects them and writes the policies. Both run once per
# database, so the sandboxed tier and the committed tier hold the same rules.
Mediate.Dev.Cluster.start(
  otp_app: :mediate,
  repos: [
    {Sandboxed, role: :app, database: :sandboxed, pool: Sandbox},
    {Mediate.TestRepos.Committed, role: :app, database: :committed, pool_size: 2},
    {Mediate.TestRepos.Owner, role: :owner, database: :committed, pool_size: 2}
  ],
  migrate: fn repo ->
    Mediate.Fixture.Tables.create!(repo)
    Mediate.Postgres.Probe.create!(repo)
    [_rls] = Ecto.Migrator.run(repo, [{Rules.version(), Rules}], :up, all: true, log: false)
    :ok
  end
)

Sandbox.mode(Sandboxed, :manual)
ExUnit.start()
