defmodule TCPServer.Connector do
  require Logger

  alias TCPServer.DataHandler, as: DataHandler

  @type socket :: :inet.socket()

  def connect(address, port) do
    case :gen_tcp.connect(address, port, [:binary, packet: 4, active: false, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.notice("Connection server -> #{address}:#{port}")

        pid = self()
        GenServer.cast(TCPServer, {:add_connection, pid})

        loop_serve(socket)

      {:error, reason} ->
        Logger.error("Error: #{reason}")

        Process.sleep(100)

        exit(:unable_to_connect)
    end
  end

  defp loop_serve(socket) do
    :inet.setopts(socket, [{:active, :once}])

    receive do
      {:tcp, ^socket, data} ->
        DataHandler.handle_data(data)

      {:tcp_closed, ^socket} ->
        Logger.notice("Connection closed")
        GenServer.cast(TCPServer, {:remove_connection})

        exit(:disconnect)

      {:tcp_error, ^socket, reason} ->
        Logger.error("TCP Error: #{reason}")
        GenServer.cast(TCPServer, {:remove_connection})

        exit(:error)

      {:send_data, type, message_id, message, :with_auth} ->
        token = GenServer.call(TCPServer, {:get_auth_token})
        id = GenServer.call(TCPServer, {:get_auth_id})

        message = id <> token <> message

        DataHandler.send_data(socket, type, message_id, message)

      {:send_data, type, message_id, message, _} ->
        DataHandler.send_data(socket, type, message_id, message)

      msg ->
        Logger.info("Unhandled message -> #{inspect(msg)}")
    after
      1000 ->
        nil
    end

    loop_serve(socket)
  end
end
