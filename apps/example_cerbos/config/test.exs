import Config

# The commit the suite runs under. The suite pins it and does not read the
# environment, so every decision the suite records names one known commit.
config :example_cerbos, commit: "policies-0001"

# The test helper configures and starts the repos on the ephemeral
# cluster after the application starts. So the application starts none.
config :example_cerbos, start_repos: false
