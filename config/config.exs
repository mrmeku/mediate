import Config

# One umbrella build serves every application, so this file imports each
# application's own configuration. Mediate.Dev.Cluster configures the test
# repos at boot, not this file.
for config <- Path.wildcard(Path.expand("../apps/*/config/config.exs", __DIR__)) do
  import_config config
end

if config_env() == :test do
  config :logger, level: :warning
end
