import Config

config :logger, :default_formatter,
  format: "\n[$time] $metadata[$level] $message\n",
  metadata: [:line, :file]

config :logger, level: :debug, truncate: :infinity

config :server, DbManager.Repo,
  database: "messenger_server",
  username: "postgres",
  hostname: "localhost"

config :server, ecto_repos: [DbManager.Repo]
