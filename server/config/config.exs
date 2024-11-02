import Config

config :logger, :default_formatter,
  truncate: :infinity,
  format: "\n[$time] $metadata[$level] $message\n"
