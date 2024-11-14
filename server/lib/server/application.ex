defmodule Server.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "4040")

    message_bin =
      <<131, 116, 0, 0, 0, 6, 119, 7, 109, 101, 115, 115, 97, 103, 101, 109, 0, 0, 0, 1, 0, 119,
        3, 116, 97, 103, 109, 0, 0, 0, 1, 0, 119, 14, 115, 101, 110, 100, 101, 114, 95, 105, 100,
        95, 104, 97, 115, 104, 109, 0, 0, 0, 1, 0, 119, 16, 114, 101, 99, 101, 105, 118, 101, 114,
        95, 105, 100, 95, 104, 97, 115, 104, 109, 0, 0, 0, 1, 0, 119, 4, 104, 97, 115, 104, 109,
        0, 0, 0, 1, 0, 119, 10, 112, 117, 98, 108, 105, 99, 95, 107, 101, 121, 109, 0, 0, 0, 1,
        0>>

    :erlang.binary_to_term(message_bin)

    children = [
      {Task.Supervisor, name: TCPServer.TaskSupervisor},
      {DbManager.Repo, []},
      {TCPServer, []},
      Supervisor.child_spec({Task, fn -> TCPServer.Acceptor.accept(port) end},
        restart: :permanent,
        id: TCPAcceptor
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
