defmodule TCPServerTester do
  use ExUnit.Case

  doctest TCPServer
  doctest TCPServer.Utils
  doctest TCPServer.DataHandler
  doctest TCPServer.Connector

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

  test "get_pid" do
    pid = GenServer.call(TCPServer, {:get_pid})
    assert is_pid(pid)
  end

  test "tcp_server" do
    pid = GenServer.call(TCPServer, {:get_pid})

    GenServer.cast(TCPServer, {:add_connection, pid})

    pid_1 = GenServer.call(TCPServer, {:get_connection_pid})

    assert is_pid(pid)
    assert pid == pid_1

    GenServer.cast(TCPServer, {:remove_connection})

    pid_2 = GenServer.call(TCPServer, {:get_connection_pid})

    assert pid_2 == nil
  end
end
