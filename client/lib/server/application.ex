defmodule Server.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "4040")
    address = ~c"127.0.0.1"

    children = [
      {Client, []},
      {ContactManager, []},
      {TCPServer, []},
      Supervisor.child_spec({Task, fn -> TCPServer.Connector.connect(address, port) end},
        restart: :permanent,
        id: TCPConnector
      )
    ]

    opts = [
      strategy: :one_for_one,
      max_restarts: 1000,
      max_seconds: 100,
      name: TCPServer.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
