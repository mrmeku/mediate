import Config

# The test helper configures and starts the repos on the ephemeral
# cluster after the application starts. So the application starts none.
config :example_postgres, start_repos: false
