defmodule TCPServer.Utils do
  import Bitwise

  @type packet_type ::
          :ack
          | :error
          | :handshake
          | :req_login
          | :req_signup
          | :req_logout
          | :req_key
          | :send_message
          | :recv_message
          | :req_messages
          | :req_pub_key

  @type packet_response_type ::
          :plain
          | :no_auth
          | :with_auth

  def get_packet_response_type(packet_type) do
    case packet_type do
      type when type == :ack or type == :error or type == :req_key ->
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
      :req_signup -> 4
      :req_logout -> 5
      :req_key -> 6
      :send_message -> 7
      :recv_message -> 8
      :req_messages -> 9
      :req_pub_key -> 10
      _ -> nil
    end
  end

  def packet_bin_to_atom(type) when is_binary(type) do
    case type do
      <<0>> -> :ack
      <<1>> -> :error
      <<2>> -> :handshake
      <<4>> -> :req_login
      <<5>> -> :req_signup
      <<6>> -> :req_logout
      <<7>> -> :req_key
      <<8>> -> :send_message
      <<9>> -> :recv_message
      <<10>> -> :req_messages
      <<11>> -> :req_pub_key
      _ -> nil
    end
  end

  def uuid() do
    perf_counter = :os.perf_counter()
    random = :rand.uniform(1_000_000)
    pid = :erlang.list_to_binary(:os.getpid())

    uuid_bytes = <<perf_counter::64, random::32>> <> pid

    :crypto.hash(:md4, uuid_bytes)
  end

  @int_byte_length 8

  def int_to_bytes(int) when int >= 0 do
    do_int_to_bytes(int, @int_byte_length, [])
    |> :binary.list_to_bin()
  end

  defp do_int_to_bytes(_, 0, acc), do: Enum.reverse(acc)

  defp do_int_to_bytes(int, n, acc) do
    byte = band(int >>> ((n - 1) * 8), 0xFF)
    do_int_to_bytes(int, n - 1, [byte | acc])
  end

  def bytes_to_int(<<>>), do: 0

  def bytes_to_int(<<byte, rest::binary>>) do
    (byte <<< (byte_size(rest) * 8)) + bytes_to_int(rest)
  end
end
