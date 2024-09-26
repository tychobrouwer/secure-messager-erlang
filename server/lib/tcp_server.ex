defmodule TCPServer do
  @moduledoc """
  Documentation for `TCPServer`.
  """

  require Logger

  @spec accept(integer) :: :ok
  def accept(port) do
    case :gen_tcp.listen(port, [:binary, packet: :line, active: true, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("Accepting connections on port #{port}")
        loop_acceptor(socket)

      {:error, reason} ->
        Logger.error("Error: #{reason}")

        Process.sleep(100)

        exit(:unable_to_listen)
    end
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    conn_id = uuid()

    Logger.info("Accepted connection: uid #{conn_id}")

    {:ok, pid} =
      Task.Supervisor.start_child(TCPServer.TaskSupervisor, fn ->
        loop_serve(client, conn_id)
      end)

    Registry.register(TCPServer.Registry, conn_id, %{pid: pid, client_id: nil})
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  defp loop_serve(socket, conn_id) do
    receive do
      # Handle incoming TCP data
      {:tcp, ^socket, data} ->
        Logger.info("Received: #{data}")

      # Handle TCP closed event
      {:tcp_closed, ^socket} ->
        Logger.info("Client connection closed")
        exit(:normal)

      # Handle TCP error event
      {:tcp_error, ^socket, reason} ->
        Logger.error("TCP error: #{reason}")
        exit(:error)

      # Handle custom messages to send data
      {:send_message, message} ->
        send_data(message, socket)
    after
      5000 ->
        nil
    end

    loop_serve(socket, conn_id)
  end

  defp send_data(message, socket) do
    case :gen_tcp.send(socket, message) do
      :ok ->
        Logger.info("Sent: #{message}")

      {:error, reason} ->
        Logger.error("Failed to send message: #{reason}")
    end
  end

  def send_message(pid, message) do
    send(pid, {:send_message, message})
  end

  @spec uuid() :: binary
  def uuid() do
    perf_counter = :os.perf_counter()
    random = :rand.uniform(1_000_000)
    pid = :erlang.list_to_binary(:os.getpid())

    uuid_bytes = <<perf_counter::64, random::32>> <> pid

    Base.encode16(:crypto.hash(:sha, uuid_bytes), case: :lower)
  end
end
