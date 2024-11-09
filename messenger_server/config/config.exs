import Config

config :logger, :default_formatter,
  format: "\n[$time] $metadata[$level] $message\n",
  metadata: [:line, :file]

config :logger, level: :notice, truncate: :infinity

config :messenger_server, DbManager.Repo,
  database: "messenger_server",
  username: "postgres",
  hostname: "localhost"

config :messenger_server, ecto_repos: [DbManager.Repo]

