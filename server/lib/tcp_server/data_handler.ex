defmodule TCPServer.DataHandler do
  require Logger

  alias TCPServer.Utils, as: Utils

  @type packet_version :: 1
  @type packet_type :: Utils.packet_type()
  @type packet_response_type :: Utils.packet_response_type()
  @type socket :: :inet.socket()

  @doc """
  Handle incoming data.
  """

  def handle_data(packet, _conn_uuid) when not is_binary(packet) or byte_size(packet) < 25,
    do: {:error, :invalid_packet}

  def handle_data(_packet, conn_uuid) when not is_binary(conn_uuid),
    do: {:error, :invalid_conn_uuid}

  def handle_data(packet, conn_uuid) do
    %{
      version: _version,
      type_bin: type_bin,
      message_id: message_id,
      data: packet_data
    } = parse_packet(packet)

    type = Utils.packet_bin_to_atom(type_bin)

    Logger.info("Received data -> #{type} : #{inspect(packet_data)}")

    packet_data = parse_packet_data(packet_data, Utils.get_packet_response_type(type))

    case {type, packet_data} do
      {_type, {:error, reason}} ->
        Logger.error(inspect(reason))

        GenServer.call(TCPServer, {:send_data, :error, conn_uuid, message_id, reason})

      {:ack, _packet_data} ->
        nil

      {:error, _packet_data} ->
        nil

      {:req_key, {_id_hash, req_id_hash}} ->
        case DbManager.Key.key(req_id_hash) do
          {:ok, key} ->
            GenServer.call(TCPServer, {:send_data, :res_key, conn_uuid, message_id, key})

          {:error, reason} ->
            GenServer.call(TCPServer, {:send_data, :error, conn_uuid, message_id, reason})
        end

      {:req_login, {id_hash, login_data}} ->
        <<nonce::binary-size(12), hashed_password::binary>> = login_data

        case DbManager.User.login(id_hash, nonce, hashed_password) do
          {:ok, token} ->
            GenServer.cast(TCPServer, {:update_connection, conn_uuid, id_hash})
            GenServer.call(TCPServer, {:send_data, :res_login, conn_uuid, message_id, token})

          {:error, reason} ->
            GenServer.call(TCPServer, {:send_data, :error, conn_uuid, message_id, reason})
        end

      {:req_signup, {id_hash, signup_data}} ->
        <<public_key::binary-size(32), nonce::binary-size(12), hashed_password::binary>> = signup_data

        case DbManager.User.signup(id_hash, public_key, nonce, hashed_password) do
          {:ok, token} ->
            GenServer.cast(TCPServer, {:update_connection, conn_uuid, id_hash})
            GenServer.call(TCPServer, {:send_data, :res_signup, conn_uuid, message_id, token})

          {:error, reason} ->
            GenServer.call(TCPServer, {:send_data, :error, conn_uuid, message_id, reason})
        end

      {:req_logout, {_id_hash, _data}} ->
        GenServer.cast(TCPServer, {:update_connection, conn_uuid, nil})
        GenServer.call(TCPServer, {:send_data, :res_logout, conn_uuid, message_id, <<0>>})

      {:message, {id_hash, message_bytes}} ->
        # message_data =
        #   try do
        #     :erlang.binary_to_term(message_bin, [:safe])
        #   rescue
        #     _ ->
        #       Logger.error("Failed to parse message")

        #       GenServer.call(
        #         TCPServer,
        #         {:send_data, :error, conn_uuid, message_id, :invalid_message_data}
        #       )

        #       exit(:failed_to_parse_message)
        #   end

        <<receiver_id_hash::binary-size(16), message_data::binary>> = message_bytes

        cond do
          # not DbManager.Message.validate(message_data) ->
          #   GenServer.call(
          #     TCPServer,
          #     {:send_data, :error, conn_uuid, message_id, :invalid_message_data}
          #   )

          not DbManager.User.exists(receiver_id_hash) ->
            GenServer.call(
              TCPServer,
              {:send_data, :error, conn_uuid, message_id, :invalid_message_receiver}
            )

          # message_data.sender_id_hash !== id_hash ->
          #   GenServer.call(
          #     TCPServer,
          #     {:send_data, :error, conn_uuid, message_id, :invalid_message_sender}
          #   )

          true ->
            message_uuid =
              DbManager.Message.receive(message_data, id_hash, receiver_id_hash)

            # case GenServer.call(
            #        TCPServer,
            #        {:get_connection_id_hash, message_data.receiver_id_hash}
            #      ) do
            #   nil ->
            #     nil

            #   receiver_id_hash ->
            #     messages_bin = :erlang.term_to_binary([message_data])

            #     GenServer.call(
            #       TCPServer,
            #       {:send_data, :res_messages, receiver_id_hash, message_id, messages_bin}
            #     )
            # end

            GenServer.call(
              TCPServer,
              {:send_data, :message, conn_uuid, message_id, message_uuid}
            )
        end

      {:req_messages, {id_hash, data}} ->
        {sender_id_hash, last_us_timestamp} =
          if byte_size(data) > 20 do
            <<sender_id_hash::binary-size(16), timestamp_us_bytes::binary>> = data

            {sender_id_hash, Utils.bytes_to_int(timestamp_us_bytes)}
          else
            {nil, Utils.bytes_to_int(data)}
          end

        messages =
          DbManager.Message.get_messages(id_hash, sender_id_hash, last_us_timestamp)

        Logger.info("Messages -> #{inspect(messages)}")

        messages_bytes =
          Enum.reduce(messages, <<>>, fn message, acc ->
            message_length = Utils.int_to_bytes(byte_size(message.message_data), 4)
            <<acc::binary, sender_id_hash::binary, message_length::binary, message.message_data::binary>>
          end)

        GenServer.call(
          TCPServer,
          {:send_data, :res_messages, conn_uuid, message_id, messages_bytes}
        )

      {:req_pub_key, {_id_hash, req_id_hash}} ->
        case DbManager.User.pub_key(req_id_hash) do
          {:ok, public_key} ->
            GenServer.call(
              TCPServer,
              {:send_data, :res_pub_key, conn_uuid, message_id, public_key}
            )

          {:error, reason} ->
            GenServer.call(
              TCPServer,
              {:send_data, :error, conn_uuid, message_id, reason}
            )
        end

      _ ->
        nil
    end
  end

  defp parse_packet(packet_data) do
    <<version::integer-size(8), type_bin::binary-size(1), message_id::binary-size(16),
      data::binary>> = packet_data

    %{
      version: version,
      type_bin: type_bin,
      message_id: message_id,
      data: data
    }
  end

  defp parse_packet_data({:error, reason}, _packet_response_type),
    do: {:error, reason}

  defp parse_packet_data(packet_data, :no_auth) when byte_size(packet_data) < 16,
    do: {:error, :invalid_packet_no_auth}

  defp parse_packet_data(packet_data, :with_auth)
       when byte_size(packet_data) < 16 + 32,
       do: {:error, :invalid_packet_with_auth}

  defp parse_packet_data(packet_data, :plain),
    do: {nil, packet_data}

  defp parse_packet_data(packet_data, :no_auth) do
    <<id_hash::binary-size(16), data::binary>> = packet_data

    {id_hash, data}
  end

  defp parse_packet_data(packet_data, :with_auth) do
    <<id_hash::binary-size(16), token::binary-size(32), data::binary>> = packet_data

    case DbManager.User.verify_token(id_hash, token) do
      {:ok, true} -> {id_hash, data}
      {:ok, false} -> {:error, :invalid_packet_auth_verify}
      {:error, reason} -> {:error, reason}
    end
  end

  def send_data(socket, type, message_id, message, retry_nr \\ 0) do
    type_int = Utils.packet_to_int(type)

    result =
      create_packet(1, type_int, message_id, message)
      |> send_packet(socket)

    case result do
      {:ok, packet} ->
        Logger.info("Sent data -> #{type} : #{inspect(packet)}")

      {:error, reason} ->
        Logger.error("Failed to send data -> #{type} : #{reason}")

        Process.sleep(500)

        if retry_nr < 10 do
          send_data(socket, type, message_id, message, retry_nr + 1)
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

  defp create_packet(version, _type_int, _message_id, _data) when version != 1,
    do: {:error, :invalid_packet_version}

  defp create_packet(_version, type_int, _message_id, _data)
       when not is_integer(type_int),
       do: {:error, :invalid_packet_type}

  defp create_packet(_version, _type_int, message_id, _data)
       when not is_binary(message_id),
       do: {:error, :invalid_packet_message_id}

  defp create_packet(version, type_int, message_id, data) when is_atom(data) do
    data_bin = :erlang.atom_to_binary(data)

    <<version::8, type_int::8>> <> message_id <> <<data_bin::binary>>
  end

  defp create_packet(version, type_int, message_id, data) when is_binary(data) do
    <<version::8, type_int::8>> <> message_id <> <<data::binary>>
  end

  defp create_packet(version, type_int, message_id, data) do
    data_bin = :erlang.term_to_binary(data)

    <<version::8, type_int::8>> <> message_id <> <<data_bin::binary>>
  end
end
