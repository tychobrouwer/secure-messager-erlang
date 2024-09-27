defmodule TCPServer do
  @moduledoc """
  Documentation for `TCPServer`.
  """

  require Logger

  @type packet_version :: 1
  @type packet_type :: :message | :handshake | :ack | :error

  @doc """
  Accept incoming TCP connections on a given port.
  """

  @spec accept(integer) :: :ok
  def accept(port) do
    case :gen_tcp.listen(port, [:binary, packet: 2, active: false, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("Accepting connections on port #{port}")
        loop_acceptor(socket)

      {:error, reason} ->
        Logger.error("Error: #{reason}")

        Process.sleep(100)

        exit(:unable_to_listen)
    end
  end

  @doc """
  Loop to accept incoming connections.
  """

  @spec loop_acceptor(integer) :: :ok
  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    conn_id = uuid()

    Logger.info("Accepted connection: uid #{conn_id}")

    {:ok, pid} =
      Task.Supervisor.start_child(TCPServer.TaskSupervisor, fn ->
        handshake_packet = create_packet(1, :handshake, conn_id)
        :gen_tcp.send(client, handshake_packet)

        loop_serve(client, conn_id)
      end)

    Registry.register(TCPServer.Registry, conn_id, %{pid: pid, client_id: nil})
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  @doc """
  Loop to serve incoming connections.
  """

  @spec loop_serve(integer, binary) :: :ok
  defp loop_serve(socket, conn_id) do
    :inet.setopts(socket, [{:active, :once}])

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
        {:tcp_}

      # Handle custom messages to send data
      {:send_message, type, message} ->
        send_data(message, type, socket)
    after
      5000 ->
        nil
    end

    loop_serve(socket, conn_id)
  end

  @doc """
  Send data to a client.
  """

  @spec send_data(binary, packet_type, integer) :: :ok | {:error, any}
  defp send_data(message, type, socket) do
    packet = create_packet(1, type, message)

    case :gen_tcp.send(socket, packet) do
      :ok ->
        Logger.info("Sent: #{Base.encode16(packet, case: :lower)}")

      {:error, reason} ->
        Logger.error("Failed to send message: #{reason}")
    end
  end

  @doc """
  Create a uuid from a perf counter, random number, and pid.
  """

  @spec uuid() :: binary
  defp uuid() do
    perf_counter = :os.perf_counter()
    random = :rand.uniform(1_000_000)
    pid = :erlang.list_to_binary(:os.getpid())

    uuid_bytes = <<perf_counter::64, random::32>> <> pid

    Base.encode16(:crypto.hash(:sha, uuid_bytes), case: :lower)
  end

  @doc """
  Create a packet from a version, type, and data.
  """

  @spec create_packet(packet_version, packet_type, binary) :: binary
  def create_packet(version, packet_type, data) do
    type =
      case packet_type do
        :message -> 0
        :handshake -> 1
        :ack -> 2
        :error -> 3
      end

    <<version::8, type::8, data::binary>>
  end

  @doc """
  Public API for sending a message to a client.
  """

  @spec send_message(integer, packet_type, binary) :: :ok | {:error, any}
  def send_message(pid, type, message) do
    send(pid, {:send_message, type, message})
  end
end
