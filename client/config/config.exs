import Config

config :logger, :default_formatter,
  format: "\n[$time] $metadata[$level] $message\n",
  metadata: [:line, :file]

config :logger, level: :notice, truncate: :infinity
