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
      :req_login,
      :req_signup,
      :req_nonce,
      :message,
      :req_messages,
      :req_uuid,
      :req_id,
      :req_pub_key
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
end
