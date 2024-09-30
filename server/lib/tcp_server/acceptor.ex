defmodule TCPServer.Acceptor do
  require Logger

  alias TCPServer.DataHandler, as: DataHandler
  alias TCPServer.Utils, as: Utils

  @type socket :: :inet.socket()

  @doc """
  Accept incoming connections on a given port.
  """

  @spec accept(integer) :: :ok
  def accept(port) do
    case :gen_tcp.listen(port, [:binary, packet: 4, active: false, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("Accepting connections on port #{port}")
        loop_acceptor(socket)

      {:error, reason} ->
        Logger.error("Error: #{reason}")
        Process.sleep(100)

        exit(:unable_to_listen)
    end
  end

  @spec loop_acceptor(socket) :: :ok
  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    conn_uuid = Utils.uuid()

    Logger.info("New connection -> uid : #{inspect(conn_uuid)}")

    {:ok, pid} =
      Task.Supervisor.start_child(TCPServer.TaskSupervisor, fn ->
        DataHandler.send_data(client, :handshake, conn_uuid, conn_uuid)

        loop_serve(client, conn_uuid)
      end)

    case :gen_tcp.controlling_process(client, pid) do
      :ok -> nil
      {:error, reason} -> Logger.warn("Failed to set controlling process -> #{reason}")
    end

    GenServer.cast(TCPServer, {:add_connection, conn_uuid, pid})

    loop_acceptor(socket)
  end

  @spec loop_serve(socket, binary) :: :ok
  defp loop_serve(socket, conn_uuid) do
    :inet.setopts(socket, [{:active, :once}])

    receive do
      {:tcp, ^socket, data} ->
        DataHandler.handle_data(data, conn_uuid)

      {:tcp_closed, ^socket} ->
        Logger.info("Client connection closed")
        GenServer.cast(TCPServer, {:remove_connection, conn_uuid})

        exit(:normal)

      {:tcp_error, ^socket, reason} ->
        Logger.warn("TCP error: #{reason}")
        GenServer.cast(TCPServer, {:remove_connection, conn_uuid})

        exit(:error)

      {:send_data, type, message} ->
        DataHandler.send_data(socket, type, conn_uuid, message)
    after
      5000 ->
        nil
    end

    loop_serve(socket, conn_uuid)
  end
end
