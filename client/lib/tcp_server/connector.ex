defmodule TCPServer.Connector do
  require Logger

  alias TCPServer.DataHandler, as: DataHandler

  @type socket :: :inet.socket()

  @spec connect(charlist, integer) :: :ok
  def connect(address, port) do
    case :gen_tcp.connect(address, port, [:binary, packet: 2, active: false, reuseaddr: true]) do
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
        Logger.error("Connection closed")
        GenServer.cast(TCPServer, {:remove_connection})

        exit(:disconnect)

      {:tcp_error, ^socket, reason} ->
        Logger.error("TCP Error: #{reason}")
        GenServer.cast(TCPServer, {:remove_connection})

        exit(:error)

      {:send_data, type, message} ->
        DataHandler.send_data(message, type, socket)
    after
      5000 ->
        GenServer.call(TCPServer, {:send_data, :message, "Hello"})
    end

    loop_serve(socket)
  end
end
