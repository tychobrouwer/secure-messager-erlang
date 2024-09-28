defmodule KeysTester do
  use ExUnit.Case, async: true
  doctest Crypt.Keys

  test "generate_keypair/0" do
    keypair = Crypt.Keys.generate_keypair()

    {public_key_test, _} = :crypto.generate_key(:eddh, :x25519, keypair.private)

    assert byte_size(keypair.public) == 32
    assert byte_size(keypair.private) == 32
    assert keypair.public == public_key_test
  end

  test "generate_eddh_secret/2" do
    keypair = Crypt.Keys.generate_keypair()
    foreign_keypair = Crypt.Keys.generate_keypair()

    shared_secret = Crypt.Keys.generate_eddh_secret(keypair, foreign_keypair.public)
    foreign_shared_secret = Crypt.Keys.generate_eddh_secret(foreign_keypair, keypair.public)

    assert byte_size(shared_secret) == 32
    assert byte_size(foreign_shared_secret) == 32
    assert shared_secret == foreign_shared_secret
  end
end
