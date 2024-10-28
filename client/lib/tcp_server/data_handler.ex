defmodule TCPServer.DataHandler do
  require Logger

  @type packet_version :: 1
  @type packet_type :: TCPServer.Utils.packet_type()
  @type socket :: :inet.socket()

  @doc """
  Handle incoming data.
  """

  @spec handle_data(binary) :: :ok
  def handle_data(packet_data) do
    %{version: _version, type_bin: type_bin, uuid: _uuid, data: data} =
      try do
        <<version::binary-size(1), type_bin::binary-size(1), uuid::binary-size(20), data::binary>> =
          packet_data

        %{version: version, type_bin: type_bin, uuid: uuid, data: data}
      catch
        _ ->
          Logger.error("Failed to parse packet data -> #{inspect(packet_data)}")

          exit(":failed_to_parse_packet_handle_data")
      end

    type = TCPServer.Utils.packet_bin_to_atom(type_bin)

    Logger.info("Received data -> #{type} : #{inspect(data)}")

    case type do
      :ack ->
        nil

      :error ->
        nil

      :handshake ->
        GenServer.cast(TCPServer, {:set_uuid, data})

        own_keypair = GenServer.call(ContactManager, {:get_keypair})

        GenServer.cast(TCPServer, {:send_data, :handshake_ack, own_keypair.public, :no_auth})

      :res_login ->
        pid = GenServer.call(TCPServer, {:get_receive_pid})
        send(pid, {:req_login_response, data})

      :res_signup ->
        pid = GenServer.call(TCPServer, {:get_receive_pid})
        send(pid, {:req_signup_response, data})

      :res_nonce ->
        pid = GenServer.call(TCPServer, {:get_receive_pid})
        send(pid, {:req_nonce_response, data})

      :res_messages ->
        Task.async(fn ->
          Client.Message.receive(data)
        end)

      :res_uuid ->
        pid = GenServer.call(TCPServer, {:get_receive_pid})
        send(pid, {:req_uuid_response, data})

      :res_id ->
        pid = GenServer.call(TCPServer, {:get_receive_pid})
        send(pid, {:req_id_response, data})

      :res_pub_key ->
        pid = GenServer.call(TCPServer, {:get_receive_pid})
        send(pid, {:req_pub_key_response, data})

      _ ->
        nil
    end
  end

  @doc """
  Send data to the client.

  If the data fails to send, retry up to 10 times before exiting.
  """

  def send_data(socket, type, message, retry_nr \\ 0) do
    type_int = TCPServer.Utils.packet_to_int(type)

    result =
      create_packet(1, type_int, message)
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

  defp create_packet(version, _type_int, _data) when version != 1,
    do: {:error, :invalid_packet_version}

  defp create_packet(_version, type_int, _data) when not is_integer(type_int),
    do: {:error, :invalid_packet_type}

  defp create_packet(_version, _type_int, data) when not is_binary(data),
    do: {:error, :invalid_packet_data}

  defp create_packet(version, type_int, data) do
    uuid = GenServer.call(TCPServer, {:get_uuid})

    if is_binary(uuid) do
      <<version::8, type_int::8>> <> uuid <> <<data::binary>>
    else
      {:error, :invalid_uuid}
    end
  end
end
