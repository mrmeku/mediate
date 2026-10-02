alias Ecto.Adapters.SQL.Sandbox
alias Mediate.Dev.TestRepos.Sandboxed

Mediate.Dev.Cluster.start(
  otp_app: :mediate_dev,
  repos: [
    {Sandboxed, role: :app, database: :sandboxed, pool: Sandbox},
    {Mediate.Dev.TestRepos.Durable, role: :app, database: :durable, pool_size: 2},
    {Mediate.Dev.TestRepos.Owner, role: :owner, database: :durable, pool_size: 2}
  ],
  migrate: fn repo ->
    _versions = Ecto.Migrator.run(repo, [{1, Mediate.Dev.TestRepos.Migration}], :up, all: true, log: false)
    :ok
  end
)

Sandbox.mode(Sandboxed, :manual)
ExUnit.start()
