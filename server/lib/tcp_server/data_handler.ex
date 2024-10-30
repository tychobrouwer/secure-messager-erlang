defmodule TCPServer.DataHandler do
  require Logger

  alias TCPServer.Utils, as: Utils

  @type packet_version :: 1
  @type packet_type :: TCPServer.Utils.packet_type()
  @type socket :: :inet.socket()

  @doc """
  Handle incoming data.
  """

  def handle_data(data, _conn_uuid) when not is_binary(data) or byte_size(data) < 22,
    do: {:error, :invalid_data}

  def handle_data(_data, conn_uuid) when not is_binary(conn_uuid),
    do: {:error, :invalid_conn_uuid}

  def handle_data(data, conn_uuid) do
    %{
      version: _version,
      type_bin: type_bin,
      uuid: uuid,
      data: data
    } = parse_packet(packet_data)

    type = Utils.packet_bin_to_atom(type_bin)
    
    packet_data = parse_packet_data(data, uuid, Utils.packet_auth_needed(type))

    Logger.info("Received data -> #{type} : #{inspect(data)}")

    case {type, packet_data} do
      {:ack, _packet_data} ->
        nil

      {:error, _packet_data} ->
        nil

      {:handshake_ack, _packet_data} ->
        GenServer.cast(TCPServer, {:update_connection, conn_uuid, nil, data})

      {:req_nonce, _packet_data} ->
        nonce = GenServer.call(UserManager, {:req_nonce, message})

        GenServer.call(TCPServer, {:send_data, :res_nonce, uuid, nonce})

      { _type, {:error, reason}} -> Logger.warning(inspect(reason))
      
      {:req_login, {user_id, hashed_password}} ->
        %{token: token, valid: valid} =
          GenServer.call(UserManager, {:req_login, uuid, user_id, hashed_password})

        if valid do
          GenServer.cast(TCPServer, {:update_connection, conn_uuid, user_id, nil})
        end

        GenServer.call(TCPServer, {:send_data, :res_login, uuid, token})

      {:req_signup, {user_id, hashed_password}} ->
        %{token: token, valid: valid} =
          GenServer.call(UserManager, {:req_signup, uuid, user_id, hashed_password})

        if valid do
          GenServer.cast(TCPServer, {:update_connection, conn_uuid, user_id, nil})
        end

        GenServer.call(TCPServer, {:send_data, :res_signup, uuid, token})

      {:message, {user_id, message_bin}} ->
        message_data = :erlang.binary_to_term(message_bin)

        valid_sender =
          GenServer.call(UserManager, {:verify_token, message_data.sender_uuid, user_id, token})

        GenServer.call(
          TCPServer,
          {:send_data, :res_messages, message_data.recipient_uuid, data}
        )

      {:req_messages, {user_id, data}} ->
        nil

      {:req_uuid, {user_id, client_id}} ->
        requested_uuid = GenServer.call(TCPServer, {:get_client_uuid, client_id})

        GenServer.call(
          TCPServer,
          {:send_data, :res_uuid, uuid, requested_uuid}
        )

      {:req_id, {user_id, client_uuid}} ->
        requested_id = GenServer.call(TCPServer, {:get_client_id, client_uuid})

        GenServer.call(
          TCPServer,
          {:send_data, :res_id, uuid, requested_id}
        )

      {:req_pub_key, {user_id, client_uuid}} ->
        public_key = GenServer.call(TCPServer, {:get_client_pub_key, client_uuid})

        GenServer.call(
          TCPServer,
          {:send_data, :res_pub_key, uuid, public_key}
        )

      _ ->
        nil
    end
  end

  defp parse_packet(packet_data) do
    <<version::integer-size(8), type_bin::binary-size(1), uuid::binary-size(20), data::binary>> =
      packet_data

    %{version: version, type_bin: type_bin, uuid: uuid, data: data}
  end

  defp parse_packet_data({:error, reason}, _uuid, _auth_needed), do: {:error, reason}

  defp parse_packet_data(packet_data, _uuid, false) when byte_size(packet_data) < 16,
    do: {:error, :invalid_packet_token}
 
  defp parse_packet_data(packet_data, _uuid, true) when byte_size(packet_data) < 16 + 29,
    do: {:error, :invalid_packet_token}

  defp parse_packet_data(packet_data, _uuid, false) do
    <<user_id::binary-size(16), data::binary>> = packet_data

    %{user_id: user_id, data: data}
  end

  defp parse_packet_data(packet_data, uuid, true) do
    <<user_id::binary-size(16), token::binary-size(29), data::binary>> = packet_data

    case GenServer.call(UserManager, {:verify_token, uuid, user_id, token}) do
      false -> {:error, :invalid_packet_verify}
      true -> %{user_id: user_id, data: data}
    end
  end

  @doc """
  Send data to the client.

  If the data fails to send, retry up to 10 times before exiting.
  """

  def send_data(socket, type, uuid, message, retry_nr \\ 0) do
    type_int = TCPServer.Utils.packet_to_int(type)

    result =
      create_packet(1, type_int, uuid, message)
      |> send_packet(socket)

    case result do
      {:ok, packet} ->
        Logger.info("Sent data -> #{type} : #{inspect(packet)}")

      {:error, reason} ->
        Logger.error("Failed to send data -> #{type} : #{reason}")

        Process.sleep(500)

        if retry_nr < 10 do
          send_data(message, type, socket, retry_nr + 1)
        else
          Logger.error("Failed to send data -> #{type} : #{reason}")

          exit(":failed_to_send_data")
        end
    end
  end

  defp send_packet({:error, reason}, _socket), do: {:error, reason}

  defp send_packet(_packet, socket) when not is_port(socket), do: {:error, :invalid_socket}

  defp send_packet(packet, socket) do
    case :gen_tcp.send(socket, packet) do
      :ok ->
        {:ok, packet}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_packet(version, _type_int, _uuid, _data) when version != 1,
    do: {:error, :invalid_packet_version}

  defp create_packet(_version, type_int, _uuid, _data) when not is_integer(type_int),
    do: {:error, :invalid_packet_type}

  defp create_packet(_version, _type_int, uuid, _data) when not is_binary(uuid),
    do: {:error, :invalid_packet_uuid}

  defp create_packet(_version, _type_int, _uuid, data) when not is_binary(data),
    do: {:error, :invalid_packet_data}

  defp create_packet(version, type_int, uuid, data) do
    <<version::8, type_int::8>> <> uuid <> <<data::binary>>
  end
end
