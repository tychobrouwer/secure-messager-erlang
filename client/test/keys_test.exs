defmodule KeysTest do
  use ExUnit.Case
  doctest Keys

  require Logger

  test "generate_keypair/0" do
    {status, public_key, private_key} = Keys.generate_keypair()

    Logger.info("public key: #{Base.encode16(public_key)}")
    Logger.info("private key: #{Base.encode16(private_key)}")

    assert status == :ok
    assert byte_size(public_key) == 65
    assert byte_size(private_key) == 32
  end

  test "generate_shared_secret/2" do
    {status, public_key, private_key} = Keys.generate_keypair()

    shared_secret = Keys.generate_shared_secret(private_key, public_key)

    Logger.info("shared secret: #{Base.encode16(shared_secret)}")

    assert status == :ok
  end
end
