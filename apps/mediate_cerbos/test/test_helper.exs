alias Ecto.Adapters.SQL.Sandbox
alias Mediate.TestRepos.Sandboxed

Mediate.Dev.Cluster.start(
  otp_app: :mediate,
  repos: [
    {Sandboxed, role: :app, database: :sandboxed, pool: Sandbox},
    {Mediate.TestRepos.Committed, role: :app, database: :committed, pool_size: 2},
    {Mediate.TestRepos.Owner, role: :owner, database: :committed, pool_size: 2}
  ],
  migrate: fn repo ->
    Mediate.Fixture.Tables.create!(repo)
  end
)

_shared = Mediate.Dev.Cerbos.start_shared(policies: "priv/conformance")

Sandbox.mode(Sandboxed, :manual)
ExUnit.start()
