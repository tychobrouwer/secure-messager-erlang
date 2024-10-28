defmodule TCPServer.Connector do
  require Logger

  alias TCPServer.DataHandler, as: DataHandler

  @type socket :: :inet.socket()

  @spec connect(charlist, integer) :: :ok
  def connect(address, port) do
    case :gen_tcp.connect(address, port, [:binary, packet: 4, active: false, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("Connection server -> #{address}:#{port}")

        pid = self()
        GenServer.cast(TCPServer, {:add_connection, pid})

        loop_serve(socket)

      {:error, reason} ->
        Logger.error("Error: #{reason}")

        Process.sleep(100)

        exit(:unable_to_connect)
    end
  end

  @spec loop_serve(socket) :: :ok
  defp loop_serve(socket) do
    :inet.setopts(socket, [{:active, :once}])

    receive do
      {:tcp, ^socket, data} ->
        DataHandler.handle_data(data)

      {:tcp_closed, ^socket} ->
        Logger.warning("Connection closed")
        GenServer.cast(TCPServer, {:remove_connection})

        exit(:disconnect)

      {:tcp_error, ^socket, reason} ->
        Logger.warning("TCP Error: #{reason}")
        GenServer.cast(TCPServer, {:remove_connection})

        exit(:error)

      {:send_data, type, message, :with_auth} ->
        token = GenServer.call(TCPServer, {:get_auth_token})
        id = GenServer.call(TCPServer, {:get_auth_id})

        message = id <> token <> message

        DataHandler.send_data(socket, type, message)

      {:send_data, type, message, :no_auth} ->
        DataHandler.send_data(socket, type, message)
    after
      1000 ->
        nil
    end

    loop_serve(socket)
  end
end
