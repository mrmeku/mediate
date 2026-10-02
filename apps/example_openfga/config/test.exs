import Config

# The test helper names the store and the server of the run. It starts a
# server on a free port and creates a store on it, and each test creates a
# store of its own. The values here are what the boot validates against the
# engine's schema before either exists.
config :example_openfga, address: "127.0.0.1:8080", store_id: "example-openfga"

# The test helper configures and starts the repos on the run's cluster
# after the application starts. So the application starts none, and no
# runner with them. A test syncs the store by hand, and a runner that
# passes beside it reads the same markers from a connection of its own.
config :example_openfga, start_repos: false
