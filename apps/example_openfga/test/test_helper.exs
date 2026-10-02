alias Ecto.Adapters.SQL.Sandbox
alias Example.Infrastructure.Repo

# The cluster, the migrations loaded once, and both repos on one database:
# `Mediate.Dev.Cluster` says what the cluster does.
migrations =
  for file <- Enum.sort(Path.wildcard("priv/repo/migrations/*.exs")) do
    [{module, _binary}] = Code.require_file(file)
    {version, _name} = Integer.parse(Path.basename(file))
    {version, module}
  end

:ok = Application.put_env(:example_openfga, :migrations, migrations)

# The cluster configures the repos under the example's `otp_app`, because
# their modules read their configuration there.
Mediate.Dev.Cluster.start(
  otp_app: :example,
  repos: [
    {Repo, role: :app, database: :sandboxed, pool: Sandbox},
    {Example.Infrastructure.OwnerRepo, role: :owner, database: :sandboxed, pool_size: 2}
  ],
  migrate: fn repo ->
    [_domain, _outbox] = Ecto.Migrator.run(repo, migrations, :up, all: true, log: false)
    :ok
  end
)

# One server for the run, on a free port with the in-memory datastore, and
# the boot store on it. The store a test reads is one of its own, and
# `ExampleOpenFGA.Store` says why. The boot store carries the model the
# run's policy release names.
server = Mediate.Dev.OpenFGA.start([])
{:ok, store} = Mediate.OpenFGA.Client.HTTP.create_store(server.http, "example-openfga-boot")

_config = Mediate.Config.boot!(engine: {Mediate.OpenFGA, address: server.http, store_id: store})

_binding =
  Mediate.OpenFGA.Binding.bind!(
    repo: Repo,
    model_file: ExampleOpenFGA.model_file(),
    mapping: ExampleOpenFGA.Infrastructure.Mapping,
    guard: ExampleOpenFGA.Infrastructure.Guard,
    author: ExampleOpenFGA.author(),
    approval: ExampleOpenFGA.approval()
  )

# The policy release into the boot store. The application leaves the
# release to the helper, because a release writes a model and the server
# keeps every model it gets. The boot pins the model id the release
# answered, so a process that asks without a store of its own asks under
# the boot store's model.
{:ok, %Mediate.PolicyRelease{policy_version: model}} = Mediate.OpenFGA.release()

_pinned =
  Mediate.Config.boot!(engine: {Mediate.OpenFGA, address: server.http, store_id: store, model_id: model})

Sandbox.mode(Repo, :manual)

ExUnit.start()
