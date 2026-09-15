alias Ecto.Adapters.SQL.Sandbox
alias Example.Infrastructure.Repo

# The cluster, the migrations loaded once, and both repos on one database:
# `docs/contributing.md` §2 has the rules.
migrations =
  for file <- Enum.sort(Path.wildcard("priv/repo/migrations/*.exs")) do
    [{module, _binary}] = Code.require_file(file)
    {version, _name} = Integer.parse(Path.basename(file))
    {version, module}
  end

:ok = Application.put_env(:example_fga, :migrations, migrations)

# The cluster configures the repos under the example's `otp_app`, because
# their modules read their configuration there.
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

# One server for the run, on a free port with the in-memory datastore, and
# a store on it for the boot the application does elsewhere. The store a
# test reads is one of its own, and `ExampleFga.Store` says why. This store
# carries the model the run's boot version names.
server = Mediate.Dev.Fga.start_shared([])
{:ok, store} = Mediate.Fga.Client.Http.create_store(server.address, "example-fga-boot")

_config = Mediate.Config.boot!(adapter: {Mediate.Fga, endpoint: server.address, store_id: store})

_binding =
  Mediate.Fga.Binding.bind!(
    repo: Repo,
    model: ExampleFga.model(),
    mapping: ExampleFga.Infrastructure.TupleMapping,
    guard: ExampleFga.Infrastructure.Guard,
    author: ExampleFga.author(),
    approval: ExampleFga.approval()
  )

# The model published into that store. The application leaves the publish
# to the helper, because a publication writes a model and the server keeps
# every model it gets. The boot pins the id the publish returns, so a
# process that asks without a store of its own asks under this store's
# model.
{:ok, %Mediate.PolicyVersion{version: model}} = Mediate.Fga.publish()

_pinned =
  Mediate.Config.boot!(adapter: {Mediate.Fga, endpoint: server.address, store_id: store, model_id: model})

Sandbox.mode(Repo, :manual)

ExUnit.start()
