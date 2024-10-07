defmodule TCPServer.DataHandler do
  require Logger

  alias TCPServer.Utils, as: Utils

  @type packet_version :: 1
  @type packet_type :: Utils.packet_type()
  @type socket :: :inet.socket()

  @doc """
  Handle incoming data.
  """

  @spec handle_data(binary) :: :ok
  def handle_data(packet_data) do
    <<_::binary-size(1), type_bin::binary-size(1), _::binary-size(20), data::binary>> =
      packet_data

    type = Utils.packet_bin_to_atom(type_bin)

    Logger.info("Received data -> #{type} : #{inspect(data)}")

    case type do
      :ack ->
        nil

      :error ->
        nil

      :handshake ->
        GenServer.cast(TCPServer, {:set_uuid, data})

        user_id = System.get_env("USER")
        own_keypair = GenServer.call(ContactManager, {:get_own_keypair})

        res_data = own_keypair.public <> user_id
        GenServer.cast(TCPServer, {:send_data, :handshake_ack, res_data})

      :res_messages ->
        #Client.Message.receive(data)
        #GenServer.call(Client, {:receive_message, data})
        Task.async(fn -> GenServer.cast(Client, {:receive_message, data}) end)
        Logger.info("after calling receive message")

      :res_uuid ->
        pid = GenServer.call(Client, {:get_loop_pid})

        send(pid, {:req_uuid_response, data})

      :res_pub_key ->
        pid = GenServer.call(Client, {:get_loop_pid})

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
    type_bin = Utils.packet_to_int(type)

    uuid = GenServer.call(TCPServer, {:get_uuid})

    <<version::8, type_bin::8>> <> uuid <> <<data::binary>>
  end
end
