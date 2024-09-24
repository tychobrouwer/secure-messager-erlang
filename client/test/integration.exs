defmodule IntegrationTest do
  use ExUnit.Case, async: true

  doctest Crypt.Ratchet
  doctest Crypt.Keys

  require Logger

  test "sending 3 messages A to B" do
    # initialize users on platform
    {private_key_A0, public_key_A0} = Crypt.Keys.generate_keypair()
    {private_key_B0, public_key_B0} = Crypt.Keys.generate_keypair()

    {private_key_A1, public_key_A1} = Crypt.Keys.generate_keypair()
    {private_key_B1, public_key_B1} = Crypt.Keys.generate_keypair()

    # A sends 3 messages to B
    r0_A = Crypt.Keys.generate_eddh_secret(private_key_A0, public_key_B0)

    {r1_A, k11_A, m11_A, i11_A} = Crypt.Ratchet.ratchet_init(r0_A, private_key_A1, public_key_B1)
    {k12_A, m12_A, i12_A} = Crypt.Ratchet.ratchet_cycle(k11_A)
    {k13_A, m13_A, i13_A} = Crypt.Ratchet.ratchet_cycle(k12_A)

    m1 = "Hello, World!"
    m2 = "Hello, World!!"
    m3 = "Hello, World!!!"

    {enc_m1, sign_1} = Crypt.encrypt_message(m1, m11_A, i11_A, private_key_A1)
    {enc_m2, sign_2} = Crypt.encrypt_message(m2, m12_A, i12_A, private_key_A1)
    {enc_m3, sign_3} = Crypt.encrypt_message(m3, m13_A, i13_A, private_key_A1)

    # B receives 3 messages from A
    r0_B = Crypt.Keys.generate_eddh_secret(private_key_B0, public_key_A0)

    {r1_B, k11_B, m11_B, i11_B} = Crypt.Ratchet.ratchet_init(r0_B, private_key_B1, public_key_A1)
    {k12_B, m12_B, i12_B} = Crypt.Ratchet.ratchet_cycle(k11_B)
    {k13_B, m13_B, i13_B} = Crypt.Ratchet.ratchet_cycle(k12_B)

    assert r1_A == r1_B
    assert k13_A == k13_B
    assert m13_A == m13_B
    assert i13_A == i13_B

    {dec_m1, valid_1} = Crypt.decrypt_message(enc_m1, m11_B, i11_B, public_key_A1, sign_1)
    {dec_m2, valid_2} = Crypt.decrypt_message(enc_m2, m12_B, i12_B, public_key_A1, sign_2)
    {dec_m3, valid_3} = Crypt.decrypt_message(enc_m3, m13_B, i13_B, public_key_A1, sign_3)

    assert dec_m1 == m1
    assert dec_m2 == m2
    assert dec_m3 == m3

    # assert valid_1 == true
    # assert valid_2 == true
    # assert valid_3 == true
  end
end
