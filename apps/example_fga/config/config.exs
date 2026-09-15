import Config

# The server the adapter asks, and the store that keeps this application's
# tuples. A deployment names the store, because it creates the store once,
# and the store then holds the tuples every node of the deployment reads.
# The runner decides how often the drain passes, and the cursor in the
# database records how far it has got.
config :example_fga,
  endpoint: System.get_env("FGA_ENDPOINT", "127.0.0.1:8080"),
  store_id: System.get_env("FGA_STORE_ID", "mediate-example")

if config_env() == :test do
  import_config "test.exs"
end
