import Config

# The test helper names the store and the server of the run. It raises a
# server on a free port and creates a store on it, and each test creates a
# store of its own. The values here are what boot validates against the
# adapter's schema before either exists.
config :example_fga, endpoint: "127.0.0.1:8080", store_id: "mediate-example"

# The test helper configures and starts the repos on the ephemeral
# cluster after the application starts. So the application starts none,
# and no drain with them. A test settles the store by hand, and a runner
# that passes beside it reads the same markers from a connection of its
# own.
config :example_fga, start_repos: false
