defmodule TCPServer.DataHandler do
  require Logger

  alias TCPServer.Utils, as: Utils

  @type packet_version :: 1
  @type packet_type :: TCPServer.Utils.packet_type()
  @type socket :: :inet.socket()

  @doc """
  Handle incoming data.
  """

  @spec handle_data(binary, binary) :: :ok
  def handle_data(data, conn_uuid) do
    <<_version::binary-size(1), type_bin::binary-size(1), uuid::binary-size(20), message::binary>> =
      data

    type = Utils.packet_bin_to_atom(type_bin)

    Logger.info("Received data -> #{type} : #{inspect(message)}")

    case type do
      :ack ->
        nil

      :error ->
        nil

      :handshake_ack ->
        <<client_pub_key::binary-size(32), client_id::binary>> = message

        GenServer.cast(TCPServer, {:update_connection, conn_uuid, client_id, client_pub_key})

      :req_login ->
        <<user_id_length::8, message::binary>> = message
        <<user_id::binary-size(user_id_length), hashed_password::binary>> = message

        result = GenServer.call(UserManager, {:req_login, conn_uuid, user_id, hashed_password})
        response = :erlang.term_to_binary(result)

        GenServer.call(TCPServer, {:send_data, :res_login, uuid, response})

      :req_signup ->
        <<user_id_length::8, message::binary>> = message
        <<user_id::binary-size(user_id_length), hashed_password::binary>> = message

        result = GenServer.call(UserManager, {:req_signup, conn_uuid, user_id, hashed_password})

        response = :erlang.term_to_binary(result)

        GenServer.call(TCPServer, {:send_data, :res_signup, uuid, response})

      :req_nonce ->
        nonce = GenServer.call(UserManager, {:req_nonce, conn_uuid, message})

        GenServer.call(TCPServer, {:send_data, :res_nonce, uuid, nonce})

      :message ->
        message_data = :erlang.binary_to_term(message)

        GenServer.call(
          TCPServer,
          {:send_data, :res_messages, message_data.recipient_uuid, message}
        )

      :req_messages ->
        nil

      :req_uuid ->
        requested_uuid = GenServer.call(TCPServer, {:get_client_uuid, message})

        GenServer.call(
          TCPServer,
          {:send_data, :res_uuid, uuid, requested_uuid}
        )

      :req_id ->
        requested_id = GenServer.call(TCPServer, {:get_client_id, message})

        GenServer.call(
          TCPServer,
          {:send_data, :res_id, uuid, requested_id}
        )

      :req_pub_key ->
        public_key = GenServer.call(TCPServer, {:get_client_pub_key, message})

        GenServer.call(
          TCPServer,
          {:send_data, :res_pub_key, uuid, public_key}
        )

      _ ->
        nil
    end
  end

  @doc """
  Send data to the client.
  """

  @spec send_data(socket, packet_type, binary, binary) :: :ok | {:error, any}
  def send_data(socket, type, uuid, message) do
    packet = create_packet(1, type, uuid, message)

    case :gen_tcp.send(socket, packet) do
      :ok ->
        Logger.info("Sent data -> #{type} : #{inspect(packet)}")

      {:error, reason} ->
        Logger.warning("Failed to send data -> #{type} : #{reason}")
    end
  end

  @doc """
  Create a packet from a version, type, and data.
  """

  @spec create_packet(packet_version, packet_type, binary, binary) :: binary
  def create_packet(version, type, uuid, data) do
    type_bin = Utils.packet_to_int(type)

    <<version::8, type_bin::8>> <> uuid <> <<data::binary>>
  end
end
