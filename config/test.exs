import Config

# Keep test output clean; the tests configure :loki_logger_modern themselves.
config :logger, :default_handler, false
