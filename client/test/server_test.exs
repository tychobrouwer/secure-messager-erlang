defmodule TCPServerTester do
  use ExUnit.Case

  doctest TCPServer
  doctest TCPServer.Utils
  doctest TCPServer.DataHandler
  doctest TCPServer.Connector

  require Logger

  test "packet_to_int_to_packet" do
    packet_types = [
      :ack,
      :error,
      :handshake,
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
end
