import Config

# The development database `nix run .#services` raises: one database, the
# two roles, and the repos, each under the role it connects as. The test
# environment leaves the repos to the ephemeral cluster and configures none
# of this.
for {repo, role} <- [
      {Example.Infrastructure.Repo, "mediate_app"},
      {Example.Infrastructure.OwnerRepo, "mediate_owner"}
    ] do
  config :example, repo,
    hostname: "127.0.0.1",
    port: 5432,
    username: role,
    database: "mediate_dev",
    pool_size: 2
end
