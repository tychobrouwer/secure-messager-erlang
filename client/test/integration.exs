defmodule IntegrationTest do
  use ExUnit.Case, async: true

  doctest Crypt.Ratchet
  doctest Crypt.Keys

  require Logger

  test "sending 3 messages A to B and from B to A" do
    # initialize users on platform
    {private_key_A0, public_key_A0} = Crypt.Keys.generate_keypair()
    {private_key_B0, public_key_B0} = Crypt.Keys.generate_keypair()

    # A sends 3 messages to B

    {private_key_A1, public_key_A1} = Crypt.Keys.generate_keypair()

    # Only needs to be generated on first ever message between A and B
    r0_A = Crypt.Keys.generate_eddh_secret(private_key_A0, public_key_B0)

    {r1_A, k11_A, m11_A, i11_A} = Crypt.Ratchet.ratchet_init(r0_A, private_key_A1, public_key_B0)
    {k12_A, m12_A, i12_A} = Crypt.Ratchet.ratchet_cycle(k11_A)
    {k13_A, m13_A, i13_A} = Crypt.Ratchet.ratchet_cycle(k12_A)

    m1 = "Hello, World!"
    m2 = "Hello, World!!"
    m3 = "Hello, World!!!"

    {enc_m1, sign_1} = Crypt.encrypt_message(m1, m11_A, i11_A, private_key_A1)
    {enc_m2, sign_2} = Crypt.encrypt_message(m2, m12_A, i12_A, private_key_A1)
    {enc_m3, sign_3} = Crypt.encrypt_message(m3, m13_A, i13_A, private_key_A1)

    # save encrypted messages and signatures to server

    # B receives 3 messages from A

    # Only needs to be generated on first ever message between A and B
    r0_B = Crypt.Keys.generate_eddh_secret(private_key_B0, public_key_A0)

    {r1_B, k11_B, m11_B, i11_B} = Crypt.Ratchet.ratchet_init(r0_B, private_key_B0, public_key_A1)
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

    # B sends 3 messages to A

    {private_key_B1, public_key_B1} = Crypt.Keys.generate_keypair()

    {r2_B, k21_B, m21_B, i21_B} = Crypt.Ratchet.ratchet_init(r1_B, private_key_B1, public_key_A1)
    {k22_B, m22_B, i22_B} = Crypt.Ratchet.ratchet_cycle(k21_B)
    {k23_B, m23_B, i23_B} = Crypt.Ratchet.ratchet_cycle(k22_B)

    m4 = "Hello, World!!!!"
    m5 = "Hello, World!!!!!"
    m6 = "Hello, World!!!!!!"

    {enc_m4, sign_4} = Crypt.encrypt_message(m4, m21_B, i21_B, private_key_B1)
    {enc_m5, sign_5} = Crypt.encrypt_message(m5, m22_B, i22_B, private_key_B1)
    {enc_m6, sign_6} = Crypt.encrypt_message(m6, m23_B, i23_B, private_key_B1)

    # save encrypted messages and signatures to server

    # A receives 3 messages from B
    {r2_A, k21_A, m21_A, i21_A} = Crypt.Ratchet.ratchet_init(r1_B, private_key_A1, public_key_B1)
    {k22_A, m22_A, i22_A} = Crypt.Ratchet.ratchet_cycle(k21_A)
    {k23_A, m23_A, i23_A} = Crypt.Ratchet.ratchet_cycle(k22_A)

    assert r2_A == r2_B
    assert k23_A == k23_B
    assert m23_A == m23_B
    assert i23_A == i23_B

    {dec_m4, valid_4} = Crypt.decrypt_message(enc_m4, m21_A, i21_A, public_key_B1, sign_4)
    {dec_m5, valid_5} = Crypt.decrypt_message(enc_m5, m22_A, i22_A, public_key_B1, sign_5)
    {dec_m6, valid_6} = Crypt.decrypt_message(enc_m6, m23_A, i23_A, public_key_B1, sign_6)

    assert dec_m4 == m4
    assert dec_m5 == m5
    assert dec_m6 == m6
  end
end
