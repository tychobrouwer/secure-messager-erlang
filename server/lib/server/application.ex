defmodule Server.Application do
  @moduledoc false

  require Logger

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "4040")

    children = [
      {Task.Supervisor, name: TCPServer.TaskSupervisor},
      {TCPServer, []},
      Supervisor.child_spec({Task, fn -> TCPServer.Acceptor.accept(port) end}, restart: :permanent)
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
