defmodule TCPServer.Utils do
  @type packet_type ::
          :ack
          | :error
          | :handshake
          | :req_login
          | :res_login
          | :req_signup
          | :res_signup
          | :req_logout
          | :res_logout
          | :req_nonce
          | :res_nonce
          | :message
          | :req_messages
          | :res_messages
          | :req_pub_key
          | :res_pub_key

  @type packet_response_type ::
          :plain
          | :no_auth
          | :with_auth

  def get_packet_response_type(packet_type) do
    case packet_type do
      type when type == :ack or type == :error or type == :req_nonce ->
        :plain

      type when type == :req_login or type == :req_signup ->
        :no_auth

      _ ->
        :with_auth
    end
  end

  def packet_to_int(type) do
    case type do
      :ack -> 0
      :error -> 1
      :handshake -> 2
      :req_login -> 3
      :res_login -> 4
      :req_signup -> 5
      :res_signup -> 6
      :req_logout -> 7
      :res_logout -> 8
      :req_nonce -> 9
      :res_nonce -> 10
      :message -> 11
      :req_messages -> 12
      :res_messages -> 13
      :req_pub_key -> 14
      :res_pub_key -> 15
      _ -> nil
    end
  end

  def packet_bin_to_atom(type) when is_binary(type) do
    case type do
      <<0>> -> :ack
      <<1>> -> :error
      <<2>> -> :handshake
      <<3>> -> :req_login
      <<4>> -> :res_login
      <<5>> -> :req_signup
      <<6>> -> :res_signup
      <<7>> -> :req_logout
      <<8>> -> :res_logout
      <<9>> -> :req_nonce
      <<10>> -> :res_nonce
      <<11>> -> :message
      <<12>> -> :req_messages
      <<13>> -> :res_messages
      <<14>> -> :req_pub_key
      <<15>> -> :res_pub_key
      _ -> nil
    end
  end
end
