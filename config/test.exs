import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :bravo, Bravo.Repo,
  username: "centinela_admin",
  password: "@dm1nC3nt1n3l4!",
  hostname: "localhost",
  database: "bravo_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bravo, BravoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "WKGBvgb83Lr7FNbvFb2X2e9KMeqwvGj1VA3Ms4qTTXPPnhHvnLGliA8cSTf8JBTK",
  server: false

# In test we don't send emails
config :bravo, Bravo.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Configure Oban for manual testing
config :bravo, Oban, testing: :manual

# Speed up the test suite by using the lowest bcrypt cost.
config :bcrypt_elixir, :log_rounds, 1

# Disable the workflow cache in tests so each test (in the sandbox) reads the
# current state machine directly from the DB without cross-test cache leakage.
config :bravo, :workflow_cache, false
