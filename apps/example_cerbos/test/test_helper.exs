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

:ok = Application.put_env(:example_cerbos, :migrations, migrations)

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

# The policy files the run's sidecar serves are a copy under `tmp/` and not
# the committed ones. A scenario that publishes a rule change writes a file
# into the directory the sidecar watches. That directory must be one `git`
# does not track. The copy also makes every publish a change to a file that
# is already there, which is what a directory watch reports.
run = Path.join([File.cwd!(), "tmp", "cerbos-" <> Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)])
policies = Path.join(run, "policies")
File.mkdir_p!(policies)
Enum.each(Path.wildcard("priv/policies/*.yaml"), &File.cp!(&1, Path.join(policies, Path.basename(&1))))

sidecar = Mediate.Dev.Cerbos.start_shared(policies: policies, dir: run)

# The address and the directory of the run's sidecar, put where every test
# reads them. The application booted against the configured address, which
# is a deployment's. The sidecar the run raised takes a free port of its
# own.
_config = Mediate.Config.boot!(adapter: {Mediate.Cerbos, address: sidecar.address})

_binding =
  Mediate.Cerbos.Binding.bind!(
    repo: Repo,
    attributes: ExampleCerbos.Infrastructure.Attributes,
    policies: sidecar.policies,
    commit: Application.fetch_env!(:example_cerbos, :commit),
    author: ExampleCerbos.author(),
    approval: ExampleCerbos.approval()
  )

# The commit the sidecar serves, published once the run's sidecar is up.
# The application publishes nothing when the cluster owns the repos, so a
# run has one policy-version event and not two.
{:ok, _published} = Mediate.Cerbos.publish()

Sandbox.mode(Repo, :manual)

ExUnit.start()
