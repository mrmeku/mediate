import Config

# The server the engine asks, the policy directory the server reads, and
# the commit of that directory. The commit is the policy version every
# decision names. It comes from the repository that merged the policy files,
# which is what POLICY_COMMIT carries in a deployment.
config :example_cerbos,
  address: "127.0.0.1:3592",
  policy_dir: "priv/policies",
  commit: System.get_env("POLICY_COMMIT", "policies-at-the-working-tree")

if config_env() == :test do
  import_config "test.exs"
end
