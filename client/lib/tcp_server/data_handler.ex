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

    Utils.exit_on_nil(type, "handle_data")

    Logger.info("Received data -> #{type} : #{inspect(data)}")

    case type do
      :ack ->
        nil

      :error ->
        nil

      :handshake ->
        GenServer.cast(TCPServer, {:set_uuid, data})

        user_id = System.get_env("USER")
        own_keypair = GenServer.call(ContactManager, {:get_keypair})

        res_data = own_keypair.public <> user_id
        GenServer.cast(TCPServer, {:send_data, :handshake_ack, res_data})

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
  """

  @spec send_data(binary, packet_type, socket) :: :ok | {:error, any}
  def send_data(message, type, socket) do
    packet = create_packet(1, type, message)

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

  @spec create_packet(packet_version, packet_type, binary) :: binary
  def create_packet(version, type, data) do
    type_bin = TCPServer.Utils.packet_to_int(type)

    uuid = GenServer.call(TCPServer, {:get_uuid})

    <<version::8, type_bin::8>> <> uuid <> <<data::binary>>
  end
end
