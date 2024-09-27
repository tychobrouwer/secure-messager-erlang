defmodule TCPServer do
  @moduledoc """
  Documentation for `TCPServer`.
  """

  require Logger
  @type packet_version :: 1
  @type packet_type :: :message | :handshake | :ack | :error

  @doc """
  Accept incoming connections on a given port.
  """

  @spec connect(charlist, integer) :: :ok
  def connect(address, port) do
    case :gen_tcp.connect(address, port, [:binary, packet: 2, active: false, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("Connection on #{address}:#{port}")

        pid = self()

        Registry.register(TCPServer.Registry, 'pid', pid)

        loop_serve(socket)

      {:error, reason} ->
        Logger.error("Error: #{reason}")

        Process.sleep(100)

        exit(:unable_to_connect)
    end
  end

  @doc """
  Loop to accept incoming connections.
  """

  defp loop_serve(socket) do
    :inet.setopts(socket, [{:active, :once}])

    receive do
      {:tcp, ^socket, data} ->
        handle_data(data, socket)

      {:tcp_closed, ^socket} ->
        Logger.error("Connection closed")
        exit(:disconnect)

      {:tcp_error, ^socket, reason} ->
        Logger.error("TCP Error: #{reason}")
        exit(:error)

      {:send_message, message} ->
        send_data(message, socket)
    after
      5000 ->
        nil
    end

    loop_serve(socket)
  end

  @doc """
  Handle incoming data.
  """

  @spec handle_data(binary, pid) :: :ok
  defp handle_data(data, socket) do
    <<packet_version::binary-size(1), packet_type::binary-size(1), message::binary>> = data

    type =
      case packet_type do
        <<0>> -> :message
        <<1>> -> :handshake
        <<2>> -> :ack
        <<3>> -> :error
      end

    case type do
      :message ->
        Logger.info("Received message: #{message}")

      :handshake ->
        Logger.info("Received handshake: #{message}")

      :ack ->
        Logger.info("Received ack: #{message}")

      :error ->
        Logger.error("Received error: #{message}")
    end
  end

  @doc """
  Send data to the server.
  """

  @spec send_data(binary, pid) :: :ok
  defp send_data(message, socket) do
    packet = create_packet(1, type, message)

    case :gen_tcp.send(socket, packet) do
      :ok ->
        Logger.info("Sent: #{Base.encode16(packet, case: :lower)}")

      {:error, reason} ->
        Logger.error("Failed to send message: #{reason}")
    end
  end

  @doc """
  Create a packet to send to the server with a version, type, and data.
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
  Public API for sending a message to the server.
  """

  @spec send_message(integer, packet_type, binary) :: :ok | {:error, any}
  def send_message(pid, message) do
    send(pid, {:send_message, message})
  end
end
