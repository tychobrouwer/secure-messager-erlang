defmodule TCPServerTest do
  use ExUnit.Case
  doctest TCPServer

  require Logger

  test "create_packet" do
    packet_type = :message
    packet_version = 1
    message = "Hello, world!"

    packet = TCPServer.DataHandler.create_packet(packet_version, packet_type, message)

    assert packet == <<1, 0, "Hello, world!">>
  end
end
