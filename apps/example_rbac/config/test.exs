import Config

# The test helper configures and starts the repos on the ephemeral
# cluster after the application starts. So the application starts none.
config :example_rbac, start_repos: false
