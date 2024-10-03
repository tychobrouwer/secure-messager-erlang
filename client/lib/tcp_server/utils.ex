defmodule TCPServer.Utils do
  @type packet_type ::
          :ack
          | :error
          | :handshake
          | :handshake_ack
          | :message
          | :req_messages
          | :res_messages
          | :req_uuid
          | :res_uuid
          | :req_pub_key
          | :res_pub_key
          | :req_update_pub_key

  @spec packet_to_int(packet_type) :: integer
  def packet_to_int(type) do
    case type do
      :ack -> 0
      :error -> 1
      :handshake -> 2
      :handshake_ack -> 3
      :message -> 4
      :req_messages -> 5
      :res_messages -> 6
      :req_uuid -> 7
      :res_uuid -> 8
      :req_pub_key -> 9
      :res_pub_key -> 10
      :req_update_pub_key -> 11
    end
  end

  @spec packet_bin_to_atom(binary) :: packet_type
  def packet_bin_to_atom(type) when is_binary(type) do
    case type do
      <<0>> -> :ack
      <<1>> -> :error
      <<2>> -> :handshake
      <<3>> -> :handshake_ack
      <<4>> -> :message
      <<5>> -> :req_messages
      <<6>> -> :res_messages
      <<7>> -> :req_uuid
      <<8>> -> :res_uuid
      <<9>> -> :req_pub_key
      <<10>> -> :res_pub_key
      <<11>> -> :req_update_pub_key
    end
  end
end