defmodule TCPServerTest do
  use ExUnit.Case
  doctest TCPServer
  doctest TCPServer.Utils
  doctest TCPServer.DataHandler
  doctest TCPServer.Acceptor

  require Logger

  test "packet_to_int_to_packet" do
    packet_types = [
      :ack,
      :error,
      :handshake,
      :handshake_ack,
      :req_login,
      :res_login,
      :req_signup,
      :res_signup,
      :req_nonce,
      :res_nonce,
      :message,
      :req_messages,
      :res_messages,
      :req_uuid,
      :res_uuid,
      :req_id,
      :res_id,
      :req_pub_key,
      :res_pub_key
    ]

    for packet_type <- packet_types do
      packet_int = TCPServer.Utils.packet_to_int(packet_type)
      packet_type_test = TCPServer.Utils.packet_bin_to_atom(<<packet_int::8>>)

      assert packet_type == packet_type_test
    end
  end

  test "uuid" do
    uuid = TCPServer.Utils.uuid()

    assert byte_size(uuid) == 20
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

    user_id_hash = :crypto.hash(:md4, "user1")

    GenServer.cast(TCPServer, {:update_connection, conn_id, user_id_hash, nil})

    client_1 = GenServer.call(TCPServer, {:get_client_id, conn_id})
    assert client_1 == user_id_hash

    GenServer.cast(TCPServer, {:remove_connection, conn_id})

    client_1 = GenServer.call(TCPServer, {:get_client_id, conn_id})

    assert client_1 == nil
  end
end
