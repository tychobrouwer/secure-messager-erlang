defmodule Server.Application do
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "4040")
    address = '127.0.0.1'

    children = [
      {Task.Supervisor, name: TCPServer.TaskSupervisor},
      {Client, []},
      {TCPServer, []},
      Supervisor.child_spec({Task, fn -> TCPServer.Connector.connect(address, port) end},
        restart: :permanent
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
