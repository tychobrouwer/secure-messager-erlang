defmodule TCPServer.Utils do
  @type packet_type ::
          :ack
          | :error
          | :handshake
          | :handshake_ack
          | :message
          | :req_messages
          | :res_messages
          | :req_public_key
          | :res_public_key

  @spec uuid() :: binary
  def uuid() do
    perf_counter = :os.perf_counter()
    random = :rand.uniform(1_000_000)
    pid = :erlang.list_to_binary(:os.getpid())

    uuid_bytes = <<perf_counter::64, random::32>> <> pid

    :crypto.hash(:sha, uuid_bytes)
  end

  @spec packet_to_int(packet_type) :: binary
  def packet_to_int(type) do
    case type do
      :ack -> 0
      :error -> 1
      :handshake -> 2
      :handshake_ack -> 3
      :message -> 4
      :req_messages -> 5
      :res_messages -> 6
      :req_public_key -> 7
      :res_public_key -> 8
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
      <<7>> -> :req_public_key
      <<8>> -> :res_public_key
    end
  end
end
