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
        GenServer.cast(TCPServer, {:update_connection, conn_uuid, nil, message})

      :req_login ->
        <<user_id::binary-size(16), hashed_password::binary>> = message

        %{token: token, valid: valid} =
          GenServer.call(UserManager, {:req_login, uuid, user_id, hashed_password})

        if valid do
          GenServer.cast(TCPServer, {:update_connection, conn_uuid, user_id, nil})
        end

        GenServer.call(TCPServer, {:send_data, :res_login, uuid, token})

      :req_signup ->
        <<user_id::binary-size(16), hashed_password::binary>> = message

        %{token: token, valid: valid} =
          GenServer.call(UserManager, {:req_signup, uuid, user_id, hashed_password})

        if valid do
          GenServer.cast(TCPServer, {:update_connection, conn_uuid, user_id, nil})
        end

        GenServer.call(TCPServer, {:send_data, :res_signup, uuid, token})

      :req_nonce ->
        nonce = GenServer.call(UserManager, {:req_nonce, message})

        GenServer.call(TCPServer, {:send_data, :res_nonce, uuid, nonce})

      :message ->
        <<user_id::binary-size(16), token::binary-size(29), message::binary>> = message
        valid = GenServer.call(UserManager, {:verify_token, uuid, user_id, token})

        if valid do
          message_data = :erlang.binary_to_term(message)

          # Somehow check if the message sender uuid is valid and corresponds to the user_id
          valid_sender =
            GenServer.call(UserManager, {:verify_token, message_data.sender_uuid, user_id, token})

          GenServer.call(
            TCPServer,
            {:send_data, :res_messages, message_data.recipient_uuid, message}
          )
        end

      :req_messages ->
        nil

      :req_uuid ->
        <<user_id::binary-size(16), token::binary-size(29), message::binary>> = message
        valid = GenServer.call(UserManager, {:verify_token, uuid, user_id, token})

        if valid do
          requested_uuid = GenServer.call(TCPServer, {:get_client_uuid, message})

          Logger.info("Requested UUID -> #{requested_uuid}")

          GenServer.call(
            TCPServer,
            {:send_data, :res_uuid, uuid, requested_uuid}
          )
        end

      :req_id ->
        <<user_id::binary-size(16), token::binary-size(29), message::binary>> = message
        valid = GenServer.call(UserManager, {:verify_token, uuid, user_id, token})

        if valid do
          requested_id = GenServer.call(TCPServer, {:get_client_id, message})

          GenServer.call(
            TCPServer,
            {:send_data, :res_id, uuid, requested_id}
          )
        end

      :req_pub_key ->
        <<user_id::binary-size(16), token::binary-size(29), message::binary>> = message
        valid = GenServer.call(UserManager, {:verify_token, uuid, user_id, token})

        if valid do
          public_key = GenServer.call(TCPServer, {:get_client_pub_key, message})

          GenServer.call(
            TCPServer,
            {:send_data, :res_pub_key, uuid, public_key}
          )
        end

      _ ->
        nil
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
