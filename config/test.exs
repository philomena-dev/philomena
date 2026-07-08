import Config

# Configure your database
config :philomena, Philomena.Repo,
  hostname: "postgres",
  username: "postgres",
  password: "postgres",
  database: "philomena_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :philomena,
  pwned_passwords: false,
  captcha: false

# Namespace OpenSearch indexes so test runs cannot touch dev data on the
# shared cluster. Search-backed tests recreate their index in setup; see
# test/CONVENTIONS.md.
config :philomena, :opensearch_index_prefix, "test_"

# External call stubbing. The mailer delivers to the test process
# (`Swoosh.TestAssertions.assert_email_sent/1`); ex_aws object storage
# operations succeed without any storage running; PhilomenaProxy.Http
# (scrapers, camo) routes through Req.Test — tests that trigger outbound
# HTTP must `Req.Test.stub(PhilomenaProxy.Http, fun)` or the request raises.
# The mailer and ex_aws defaults set in config/runtime.exs are skipped for
# the test environment so these values win.
config :philomena, Philomena.Mailer, adapter: Swoosh.Adapters.Test

config :ex_aws, http_client: Philomena.ExAwsHttpClientStub

config :philomena, :req_options, plug: {Req.Test, PhilomenaProxy.Http}

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :philomena, PhilomenaWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warning
