defmodule IntegrationTest do
  use ExUnit.Case, async: true

  require Logger

  test "sending 3 messages A to B and from B to A" do
    # initialize users on platform
    {private_key_A0, public_key_A0} = Crypt.Keys.generate_keypair()
    {private_key_B0, public_key_B0} = Crypt.Keys.generate_keypair()

    # A sends 3 messages to B

    {private_key_A1, public_key_A1} = Crypt.Keys.generate_keypair()

    # Initialize dh ratchet (TODO this should be 3dh ratchet method)
    r0_A = Crypt.Keys.generate_eddh_secret(private_key_A0, public_key_B0)
    dh_ratchet_0_A = %{root_key: r0_A, child_key: nil, iv_key: nil}

    # Rotate dh ratchet
    dh_ratchet_1_A = Crypt.Ratchet.ratchet_init(dh_ratchet_0_A, private_key_A1, public_key_B0)

    # Rotate message ratchet 3 times
    m_ratchet_11_A = Crypt.Ratchet.ratchet_cycle(dh_ratchet_1_A.child_key)
    m_ratchet_12_A = Crypt.Ratchet.ratchet_cycle(m_ratchet_11_A.root_key)
    m_ratchet_13_A = Crypt.Ratchet.ratchet_cycle(m_ratchet_12_A.root_key)

    m1 = "Hello, World!"
    m2 = "Hello, World!!"
    m3 = "Hello, World!!!"

    {enc_m1, sign_1} =
      Crypt.encrypt_message(
        m1,
        m_ratchet_11_A.child_key,
        m_ratchet_11_A.iv_key,
        private_key_A1
      )

    {enc_m2, sign_2} =
      Crypt.encrypt_message(
        m2,
        m_ratchet_12_A.child_key,
        m_ratchet_12_A.iv_key,
        private_key_A1
      )

    {enc_m3, sign_3} =
      Crypt.encrypt_message(
        m3,
        m_ratchet_13_A.child_key,
        m_ratchet_13_A.iv_key,
        private_key_A1
      )

    # save encrypted messages and signatures to server

    # B receives 3 messages from A

    # Initialize dh ratchet (TODO this should be 3dh ratchet method)
    r0_B = Crypt.Keys.generate_eddh_secret(private_key_B0, public_key_A0)
    dh_ratchet_0_B = %{root_key: r0_B, child_key: nil, iv_key: nil}

    # Rotate dh ratchet
    dh_ratchet_1_B = Crypt.Ratchet.ratchet_init(dh_ratchet_0_B, private_key_B0, public_key_A1)

    # Rotate message ratchet 3 times
    m_ratchet_11_B = Crypt.Ratchet.ratchet_cycle(dh_ratchet_1_B.child_key)
    m_ratchet_12_B = Crypt.Ratchet.ratchet_cycle(m_ratchet_11_B.root_key)
    m_ratchet_13_B = Crypt.Ratchet.ratchet_cycle(m_ratchet_12_B.root_key)

    assert dh_ratchet_0_A == dh_ratchet_0_B
    assert dh_ratchet_1_A == dh_ratchet_1_B
    assert m_ratchet_11_A == m_ratchet_11_B
    assert m_ratchet_12_A == m_ratchet_12_B
    assert m_ratchet_13_A == m_ratchet_13_B

    {dec_m1, _} =
      Crypt.decrypt_message(
        enc_m1,
        m_ratchet_11_B.child_key,
        m_ratchet_11_B.iv_key,
        public_key_A1,
        sign_1
      )

    {dec_m2, _} =
      Crypt.decrypt_message(
        enc_m2,
        m_ratchet_12_B.child_key,
        m_ratchet_12_B.iv_key,
        public_key_A1,
        sign_2
      )

    {dec_m3, _} =
      Crypt.decrypt_message(
        enc_m3,
        m_ratchet_13_B.child_key,
        m_ratchet_13_B.iv_key,
        public_key_A1,
        sign_3
      )

    assert dec_m1 == m1
    assert dec_m2 == m2
    assert dec_m3 == m3

    # B sends 3 messages to A

    {private_key_B1, public_key_B1} = Crypt.Keys.generate_keypair()

    dh_ratchet_2_B = Crypt.Ratchet.ratchet_init(dh_ratchet_1_B, private_key_B1, public_key_A1)
    m_ratchet_21_B = Crypt.Ratchet.ratchet_cycle(dh_ratchet_2_B.child_key)
    m_ratchet_22_B = Crypt.Ratchet.ratchet_cycle(m_ratchet_21_B.root_key)
    m_ratchet_23_B = Crypt.Ratchet.ratchet_cycle(m_ratchet_22_B.root_key)

    m4 = "Hello, World!!!!"
    m5 = "Hello, World!!!!!"
    m6 = "Hello, World!!!!!!"

    {enc_m4, sign_4} =
      Crypt.encrypt_message(
        m4,
        m_ratchet_21_B.child_key,
        m_ratchet_21_B.iv_key,
        private_key_B1
      )

    {enc_m5, sign_5} =
      Crypt.encrypt_message(
        m5,
        m_ratchet_22_B.child_key,
        m_ratchet_22_B.iv_key,
        private_key_B1
      )

    {enc_m6, sign_6} =
      Crypt.encrypt_message(
        m6,
        m_ratchet_23_B.child_key,
        m_ratchet_23_B.iv_key,
        private_key_B1
      )

    # save encrypted messages and signatures to server

    # A receives 3 messages from B

    dh_ratchet_2_A = Crypt.Ratchet.ratchet_init(dh_ratchet_1_A, private_key_A1, public_key_B1)
    m_ratchet_21_A = Crypt.Ratchet.ratchet_cycle(dh_ratchet_2_A.child_key)
    m_ratchet_22_A = Crypt.Ratchet.ratchet_cycle(m_ratchet_21_A.root_key)
    m_ratchet_23_A = Crypt.Ratchet.ratchet_cycle(m_ratchet_22_A.root_key)

    assert dh_ratchet_2_A == dh_ratchet_2_B
    assert m_ratchet_21_A == m_ratchet_21_B
    assert m_ratchet_22_A == m_ratchet_22_B
    assert m_ratchet_23_A == m_ratchet_23_B

    {dec_m4, _} =
      Crypt.decrypt_message(
        enc_m4,
        m_ratchet_21_A.child_key,
        m_ratchet_21_A.iv_key,
        public_key_B1,
        sign_4
      )

    {dec_m5, _} =
      Crypt.decrypt_message(
        enc_m5,
        m_ratchet_22_A.child_key,
        m_ratchet_22_A.iv_key,
        public_key_B1,
        sign_5
      )

    {dec_m6, _} =
      Crypt.decrypt_message(
        enc_m6,
        m_ratchet_23_A.child_key,
        m_ratchet_23_A.iv_key,
        public_key_B1,
        sign_6
      )

    assert dec_m4 == m4
    assert dec_m5 == m5
    assert dec_m6 == m6
  end
end
