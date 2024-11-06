defmodule TCPServer.DataHandler do
  require Logger

  @type packet_version :: 1
  @type packet_type :: TCPServer.Utils.packet_type()
  @type socket :: :inet.socket()

  @doc """
  Handle incoming data.
  """

  def handle_data(data, _conn_uuid) when not is_binary(data) or byte_size(data) < 22,
    do: {:error, :invalid_packet_data}

  def handle_data(packet) do
    %{
      version: _version,
      type_bin: type_bin,
      uuid: _uuid,
      message_id: message_id,
      data: packet_data
    } = parse_packet(packet)

    type = TCPServer.Utils.packet_bin_to_atom(type_bin)

    Logger.info("Received data -> #{type} : #{inspect(packet)}")

    case type do
      :ack ->
        nil

      :error ->
        Logger.error("Received error -> #{packet_data}")

        case GenServer.call(TCPServer, {:get_receive_pid, message_id}) do
          nil -> nil
          pid -> send(pid, {:req_error_response, packet_data})
        end

      :handshake ->
        GenServer.cast(TCPServer, {:set_uuid, packet_data})

        case GenServer.call(ContactManager, {:get_keypair}) do
          nil ->
            nil

          own_keypair ->
            GenServer.cast(
              TCPServer,
              {:send_data, :handshake_ack, message_id, own_keypair.public}
            )
        end

      :res_login ->
        case GenServer.call(TCPServer, {:get_receive_pid, message_id}) do
          nil -> nil
          pid -> send(pid, {:req_response, packet_data})
        end

      :res_signup ->
        case GenServer.call(TCPServer, {:get_receive_pid, message_id}) do
          nil -> nil
          pid -> send(pid, {:req_response, packet_data})
        end

      :res_nonce ->
        case GenServer.call(TCPServer, {:get_receive_pid, message_id}) do
          nil -> nil
          pid -> send(pid, {:req_response, packet_data})
        end

      :res_messages ->
        Task.async(fn ->
          Client.Message.receive(packet_data)
        end)

      :res_uuid ->
        case GenServer.call(TCPServer, {:get_receive_pid, message_id}) do
          nil -> nil
          pid -> send(pid, {:req_response, packet_data})
        end

      :res_id ->
        case GenServer.call(TCPServer, {:get_receive_pid, message_id}) do
          nil -> nil
          pid -> send(pid, {:req_response, packet_data})
        end

      :res_pub_key ->
        case GenServer.call(TCPServer, {:get_receive_pid, message_id}) do
          nil -> nil
          pid -> send(pid, {:req_response, packet_data})
        end

      _ ->
        nil
    end
  end

  defp parse_packet(packet) do
    <<version::integer-size(8), type_bin::binary-size(1), uuid::binary-size(20),
      message_id::binary-size(20),
      data::binary>> =
      packet

    %{version: version, type_bin: type_bin, uuid: uuid, message_id: message_id, data: data}
  end

  @doc """
  Send data to the client.

  If the data fails to send, retry up to 10 times before exiting.
  """

  def send_data(socket, type, message_id, message, retry_nr \\ 0) do
    type_int = TCPServer.Utils.packet_to_int(type)

    result =
      create_packet(1, type_int, message_id, message)
      |> send_packet(socket)

    case result do
      {:ok, packet} ->
        Logger.info("Sent data -> #{type} : #{inspect(packet)}")

        message_id

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

  defp create_packet(_version, type_int, _message_id, _data) when not is_integer(type_int),
    do: {:error, :invalid_packet_type}

  defp create_packet(_version, _type_int, message_id, _data) when not is_binary(message_id),
    do: {:error, :invalid_packet_message_id}

  defp create_packet(_version, _type_int, _message_id, data) when not is_binary(data),
    do: {:error, :invalid_packet_data}

  defp create_packet(version, type_int, message_id, data) do
    uuid = GenServer.call(TCPServer, {:get_uuid})

    if is_binary(uuid) do
      <<version::8, type_int::8>> <> uuid <> message_id <> <<data::binary>>
    else
      {:error, :invalid_uuid}
    end
  end
end
