defmodule TCPServer.Acceptor do
  require Logger

  alias TCPServer.DataHandler, as: DataHandler
  alias TCPServer.Utils, as: Utils

  @type socket :: :inet.socket()

  @doc """
  Accept incoming connections on a given port.
  """

  def accept(port) do
    case :gen_tcp.listen(port, [:binary, packet: 4, active: false, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.notice("Accepting connections on port #{port}")
        loop_acceptor(socket)

      {:error, reason} ->
        Logger.error("Error: #{reason}")
        Process.sleep(100)

        exit(:unable_to_listen)
    end
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    conn_uuid = Utils.uuid()

    Logger.notice("New connection -> conn_uuid : #{inspect(conn_uuid)}")

    {:ok, pid} =
      Task.Supervisor.start_child(TCPServer.TaskSupervisor, fn ->
        message_id = :crypto.hash(:md4, <<0>>)
        DataHandler.send_data(client, :handshake, conn_uuid, message_id, conn_uuid)

        loop_serve(client, conn_uuid)
      end)

    case :gen_tcp.controlling_process(client, pid) do
      :ok -> nil
      {:error, reason} -> Logger.error("Failed to set controlling process -> #{reason}")
    end

    GenServer.cast(TCPServer, {:add_connection, conn_uuid, pid})

    loop_acceptor(socket)
  end

  defp loop_serve(socket, conn_uuid) do
    :inet.setopts(socket, [{:active, :once}])

    receive do
      {:tcp, ^socket, data} ->
        DataHandler.handle_data(data, conn_uuid)

      {:tcp_closed, ^socket} ->
        Logger.notice("Client connection closed")
        GenServer.cast(TCPServer, {:remove_connection, conn_uuid})

        exit(:normal)

      {:tcp_error, ^socket, reason} ->
        Logger.error("TCP error: #{reason}")
        GenServer.cast(TCPServer, {:remove_connection, conn_uuid})

        exit(:error)

      {:send_data, type, message_id, message} ->
        DataHandler.send_data(socket, type, message_id, message)

      msg ->
        Logger.info("Unhandled message -> #{inspect(msg)}")
    after
      5000 ->
        nil
    end

    loop_serve(socket, conn_uuid)
  end
end
