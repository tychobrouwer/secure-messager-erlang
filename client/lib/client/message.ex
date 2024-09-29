defmodule Client.Message do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: Client.contact()

  @doc """
  Send a message to a recipient.

  ## Examples

      iex>recipient_public_key = Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459")
      iex>{keypair, dh_ratchet, m_ratchet} = ClientTest.init_client(recipient_public_key)
      iex> {dh_ratchet, m_ratchet, enc_m} = ClientTest.send_message("Hello, World!", dh_ratchet, m_ratchet, keypair, recipient_public_key)
      {dh_ratchet, m_ratchet, enc_m}
  """

  @spec send_message(binary, binary) :: :ok
  def send_message(message, recipient_uuid) do
    keypair = GenServer.call(Client, {:get_contact_own_keypair, recipient_uuid})
    dh_ratchet = GenServer.call(Client, {:get_contact_dh_ratchet, recipient_uuid})
    m_ratchet = GenServer.call(Client, {:get_contact_m_ratchet, recipient_uuid})

    Logger.info("Sending message to #{recipient_uuid}")

    {dh_ratchet, m_ratchet, keypair} =
      if m_ratchet == nil do
        own_public_key = keypair.public
        recipient_public_key = GenServer.call(Client, {:get_contact_key, recipient_uuid})

        if recipient_public_key == nil do
          GenServer.cast(TCPClient, {:send_data, :req_public_key, recipient_uuid})

          receive do
            {:public_key_response, response} ->
              recipient_public_key = response
              GenServer.cast(Client, {:update_contact_key, recipient_uuid, recipient_public_key})

              Logger.info("Received public key: #{recipient_public_key}")
          after
            5000 ->
              Logger.error("Timeout waiting for public key")
              exit(:timeout)
          end
        end

        keypair = Crypt.Keys.generate_keypair()
        dh_ratchet = Crypt.Ratchet.rk_cycle(dh_ratchet, keypair, recipient_public_key)
        m_ratchet = Crypt.Ratchet.ck_cycle(dh_ratchet.child_key)

        {dh_ratchet, m_ratchet, keypair}
      else
        m_ratchet = Crypt.Ratchet.ck_cycle(m_ratchet.root_key)

        {dh_ratchet, m_ratchet, keypair}
      end

    GenServer.cast(
      Client,
      {:update_contact_cycle, recipient_uuid, keypair, dh_ratchet, m_ratchet}
    )

    {encrypted_message, message_tag, signature} =
      Crypt.encrypt_message(message, m_ratchet.child_key, keypair.private)

    Logger.info(
      "encrpyted message send: \"#{Base.encode64(encrypted_message)}\", message tag: \"#{Base.encode64(message_tag)}\", signature: \"#{Base.encode64(signature)}\""
    )

    data = %{
      user_uuid: GenServer.call(Client, :get_user_uuid),
      recipient_uuid: recipient_uuid,
      message_uuid: Client.Utils.uuid(),
      tag: message_tag,
      hash: signature,
      public_key: keypair.public,
      message: encrypted_message
    }

    GenServer.call(TCPServer, {:send_data, :message, :erlang.term_to_binary(data)})
  end
end
