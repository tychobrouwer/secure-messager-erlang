defmodule TCPServerTest do
  use ExUnit.Case
  doctest TCPServer
  doctest TCPServer.Utils
  doctest TCPServer.DataHandler
  doctest TCPServer.Acceptor

  require Logger

  test "create_packet" do
    packet_type = :message
    packet_version = 1
    message = "Hello, world!"

    packet = TCPServer.DataHandler.create_packet(packet_version, packet_type, message)

    assert packet == <<1, 4, "Hello, world!">>
  end

  test "packet_to_int" do
    assert TCPServer.Utils.packet_to_int(:ack) == 0
    assert TCPServer.Utils.packet_to_int(:error) == 1
    assert TCPServer.Utils.packet_to_int(:handshake) == 2
    assert TCPServer.Utils.packet_to_int(:handshake_ack) == 3
    assert TCPServer.Utils.packet_to_int(:message) == 4
  end

  test "packet_bin_to_atom" do
    assert TCPServer.Utils.packet_bin_to_atom(<<0>>) == :ack
    assert TCPServer.Utils.packet_bin_to_atom(<<1>>) == :error
    assert TCPServer.Utils.packet_bin_to_atom(<<2>>) == :handshake
    assert TCPServer.Utils.packet_bin_to_atom(<<3>>) == :handshake_ack
    assert TCPServer.Utils.packet_bin_to_atom(<<4>>) == :message
  end

  test "uuid" do
    uuid = TCPServer.Utils.uuid()

    assert byte_size(uuid) == 40
    assert is_binary(uuid)
  end

  test "get_pid" do
    pid = GenServer.call(TCPServer, {:get_pid})
    assert is_pid(pid)
  end

  test "tcp_server" do
    pid = GenServer.call(TCPServer, {:get_pid})

    conn_id = TCPServer.Utils.uuid()

    GenServer.cast(TCPServer, {:add_connection, conn_id, pid})
    client_1 = GenServer.call(TCPServer, {:get_client_id, conn_id})

    assert client_1 == nil

    GenServer.cast(TCPServer, {:update_connection, conn_id, "user1"})

    client_1 = GenServer.call(TCPServer, {:get_client_id, conn_id})
    assert client_1 == "user1"

    GenServer.cast(TCPServer, {:remove_connection, conn_id})

    client_1 = GenServer.call(TCPServer, {:get_client_id, conn_id})

    assert client_1 == nil
  end
end
