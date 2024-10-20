defmodule TCPServer.Utils do
  @type packet_type ::
          :ack
          | :error
          | :handshake
          | :handshake_ack
          | :req_login
          | :res_login
          | :req_signup
          | :res_signup
          | :req_nonce
          | :res_nonce
          | :message
          | :req_messages
          | :res_messages
          | :req_uuid
          | :res_uuid
          | :req_id
          | :res_id
          | :req_pub_key
          | :res_pub_key
          | :req_update_pub_key

  @spec packet_to_int(packet_type) :: integer | nil
  def packet_to_int(type) do
    case type do
      :ack -> 0
      :error -> 1
      :handshake -> 2
      :handshake_ack -> 3
      :req_login -> 4
      :res_login -> 5
      :req_signup -> 6
      :res_signup -> 7
      :req_nonce -> 8
      :res_nonce -> 9
      :message -> 10
      :req_messages -> 11
      :res_messages -> 12
      :req_uuid -> 13
      :res_uuid -> 14
      :req_id -> 15
      :res_id -> 16
      :req_pub_key -> 17
      :res_pub_key -> 18
      :req_update_pub_key -> 19
      _ -> nil
    end
  end

  @spec packet_bin_to_atom(binary) :: packet_type | nil
  def packet_bin_to_atom(type) when is_binary(type) do
    case type do
      <<0>> -> :ack
      <<1>> -> :error
      <<2>> -> :handshake
      <<3>> -> :handshake_ack
      <<4>> -> :req_login
      <<5>> -> :res_login
      <<6>> -> :req_signup
      <<7>> -> :res_signup
      <<8>> -> :req_nonce
      <<9>> -> :res_nonce
      <<10>> -> :message
      <<11>> -> :req_messages
      <<12>> -> :res_messages
      <<13>> -> :req_uuid
      <<14>> -> :res_uuid
      <<15>> -> :req_id
      <<16>> -> :res_id
      <<17>> -> :req_pub_key
      <<18>> -> :res_pub_key
      <<19>> -> :req_update_pub_key
      _ -> nil
    end
  end

  @spec uuid() :: binary
  def uuid() do
    perf_counter = :os.perf_counter()
    random = :rand.uniform(1_000_000)
    pid = :erlang.list_to_binary(:os.getpid())

    uuid_bytes = <<perf_counter::64, random::32>> <> pid

    :crypto.hash(:sha, uuid_bytes)
  end
end
