defmodule ClientTest do
  use ExUnit.Case, async: true

  require Logger

  test "start" do
    assert Client.start() == :ok
  end

  test "send_message+receive_message" do
    recipient_public_key =
      Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")

    {keypair, dh_ratchet, m_ratchet} = Client.init_client(recipient_public_key)

    {dh_ratchet_1, m_ratchet_1, keypair_1} =
      Client.send_message(
        "Hello, World!",
        dh_ratchet,
        m_ratchet,
        keypair,
        recipient_public_key
      )

    {dh_ratchet_2, m_ratchet_2, keypair_2} =
      Client.send_message(
        "Hello, World! 2",
        dh_ratchet_1,
        m_ratchet_1,
        keypair_1,
        recipient_public_key
      )

    assert dh_ratchet_1 == dh_ratchet_2
    assert m_ratchet_1 != m_ratchet_2
    assert keypair_1 == keypair_2
  end
end
