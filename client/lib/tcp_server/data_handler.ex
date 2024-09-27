defmodule TCPServer.DataHandler do
  require Logger

  @type packet_version :: 1
  @type packet_type :: :message | :handshake | :handshake_ack | :ack | :error
  @type socket :: :inet.socket()

  @doc """
  Handle incoming data.
  """

  @spec handle_data(binary) :: :ok
  def handle_data(data) do
    <<packet_version::binary-size(1), packet_type::binary-size(1), message::binary>> = data

    type =
      case packet_type do
        <<0>> -> :message
        <<1>> -> :handshake
        <<2>> -> :handshake_ack
        <<3>> -> :ack
        <<4>> -> :error
      end

    Logger.info("Received data -> #{type} : #{data}")

    case type do
      :message ->
        nil

      :handshake ->
        user_id = System.get_env("USER")
        GenServer.call(TCPServer, {:send_data, :handshake_ack, user_id})

      :ack ->
        nil

      :error ->
        nil

      _ ->
        nil
    end
  end

  @doc """
  Send data to the client.
  """

  @spec send_data(binary, packet_type, socket) :: :ok | {:error, any}
  def send_data(message, type, socket) do
    packet = create_packet(1, type, message)

    case :gen_tcp.send(socket, packet) do
      :ok ->
        Logger.info("Sent data -> #{type} : #{packet}")

      {:error, reason} ->
        Logger.error("Failed to send data -> #{type} : #{packet}")
    end
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
        :handshake_ack -> 2
        :ack -> 3
        :error -> 4
      end

    <<version::8, type::8, data::binary>>
  end
end
