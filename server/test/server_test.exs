defmodule TCPServerTest do
  use ExUnit.Case
  doctest TCPServer

  require Logger

  test "create_packet" do
    packet_type = :message
    packet_version = 1
    message = "Hello, world!"

    packet = TCPServer.create_packet(packet_version, packet_type, message)
  end
end
