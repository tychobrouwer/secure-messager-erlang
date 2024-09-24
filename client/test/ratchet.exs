defmodule RatchetTest do
  use ExUnit.Case
  doctest Crypt.Ratchet

  require Logger

  test "next_chain_key/1" do
    chain_key = Base.decode("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")

    {status, key, outkey, iv} = Crypt.Ratchet.next_chain_key(chain_key)

    Logger.debug("key: #{Base.encode16(key)}")
    Logger.debug("outkey: #{Base.encode16(outkey)}")
    Logger.debug("iv: #{Base.encode16(iv)}")

    assert status == :ok
    assert byte_size(key) == 32
    assert byte_size(outkey) == 32
    assert byte_size(iv) == 16
  end
end
