import Config

# The server the engine asks, and the store that keeps this application's
# tuples. A deployment names the store, because it creates the store once,
# and the store then holds the tuples every node of the deployment reads.
# The relay decides how often the runner passes, and the cursor in the
# database records how far it has got.
config :example_openfga,
  address: System.get_env("OPENFGA_ADDRESS", "127.0.0.1:8080"),
  store_id: System.get_env("OPENFGA_STORE_ID", "example-openfga")

if config_env() == :test do
  import_config "test.exs"
end
