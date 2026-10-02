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

# The run's server watches a copy of the policy files in a run directory
# under `tmp/`, which git does not track. So nothing a run does reaches the
# files git tracks, and a change to the copy is a change to a file that is
# already there, which is what a directory watch reports.
run_dir = Path.join([File.cwd!(), "tmp", "cerbos-" <> Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)])
policy_dir = Path.join(run_dir, "policies")
File.mkdir_p!(policy_dir)
Enum.each(Path.wildcard("priv/policies/*.yaml"), &File.cp!(&1, Path.join(policy_dir, Path.basename(&1))))

server = Mediate.Dev.Cerbos.start(policy_dir: policy_dir, dir: run_dir)

# The application booted against the configured address, which is a
# deployment's. The run's server takes a free port of its own, so the boot
# runs again against it, and the binding against the run's policy
# directory.
_config = Mediate.Config.boot!(engine: {Mediate.Cerbos, address: server.http})

_binding =
  Mediate.Cerbos.Binding.bind!(
    repo: Repo,
    declarations: ExampleCerbos.Infrastructure.Declarations,
    policy_dir: server.policy_dir,
    commit: Application.fetch_env!(:example_cerbos, :commit),
    author: ExampleCerbos.author(),
    approval: ExampleCerbos.approval()
  )

# The application leaves the policy release to whoever starts the repos, and
# here the cluster does. So a run has one policy release and not two.
{:ok, _release} = Mediate.Cerbos.release()

Sandbox.mode(Repo, :manual)

ExUnit.start()
