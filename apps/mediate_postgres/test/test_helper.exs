alias Ecto.Adapters.SQL.Sandbox
alias Mediate.Postgres.Conformance.Reference
alias Mediate.TestRepos.Sandboxed

# The owner role creates the world's tables. Then the conformance
# migration protects them and writes the rules. Both run once per
# database, so the sandboxed tier and the durable tier hold the same rules.
Mediate.Dev.Cluster.start(
  otp_app: :mediate,
  repos: [
    {Sandboxed, role: :app, database: :sandboxed, pool: Sandbox},
    {Mediate.TestRepos.Durable, role: :app, database: :durable, pool_size: 2},
    {Mediate.TestRepos.Owner, role: :owner, database: :durable, pool_size: 2}
  ],
  migrate: fn repo ->
    Mediate.Fixture.Tables.create!(repo)
    Mediate.Postgres.Probe.create!(repo)
    [_rls] = Ecto.Migrator.run(repo, [{Reference.version(), Reference}], :up, all: true, log: false)
    :ok
  end
)

Sandbox.mode(Sandboxed, :manual)
ExUnit.start()
