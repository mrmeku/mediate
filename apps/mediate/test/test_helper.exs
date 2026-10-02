alias Ecto.Adapters.SQL.Sandbox
alias Mediate.TestRepos.Sandboxed

Mediate.Dev.Cluster.start(
  otp_app: :mediate,
  repos: [
    {Sandboxed, role: :app, database: :sandboxed, pool: Sandbox},
    {Mediate.TestRepos.Durable, role: :app, database: :durable, pool_size: 2},
    {Mediate.TestRepos.Owner, role: :owner, database: :durable, pool_size: 2}
  ],
  migrate: fn repo -> Mediate.Fixture.Tables.create!(repo) end
)

Sandbox.mode(Sandboxed, :manual)
ExUnit.start()
