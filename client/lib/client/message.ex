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

  @spec send(binary, binary) :: :ok
  def send(message, recipient_uuid) do
    keypair = GenServer.call(Client, {:get_contact_own_keypair, recipient_uuid})
    dh_ratchet = GenServer.call(Client, {:get_contact_dh_ratchet, recipient_uuid})
    m_ratchet = GenServer.call(Client, {:get_contact_m_ratchet, recipient_uuid})

    {dh_ratchet, m_ratchet, keypair} =
      if m_ratchet == nil do
        recipient_public_key = Client.Contact.get_contact_pub_key(recipient_uuid)

        keypair = Crypt.Keys.generate_keypair()

        GenServer.cast(TCPServer, {:send_data, :req_update_pub_key, keypair.public})

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

    {encrypted_message, message_tag, mac_hash} =
      Crypt.Message.encrypt(message, m_ratchet.child_key, keypair.private)

    Logger.info(
      "encrpyted message send: \"#{Base.encode64(encrypted_message)}\", message tag: \"#{Base.encode64(message_tag)}\", signature: \"#{Base.encode64(mac_hash)}\""
    )

    data = %{
      sender_uuid: GenServer.call(TCPServer, {:get_uuid}),
      recipient_uuid: recipient_uuid,
      message_uuid: Client.Utils.uuid(),
      tag: message_tag,
      hash: mac_hash,
      public_key: keypair.public,
      message: encrypted_message
    }

    GenServer.call(TCPServer, {:send_data, :message, :erlang.term_to_binary(data)})
  end

  @spec receive(binary) :: :ok
  def receive(message) do
    message_data = :erlang.binary_to_term(message)

    Logger.info("Received message -> #{inspect(message_data)}")

    # def decrypt(encrypted_message, message_tag, foreign_public_key, hash, message_key, private_key) do

    {decrypted_message, valid} =
      Crypt.Message.decrypt(
        message_data.message,
        message_data.tag,
        message_data.public_key,
        message_data.hash
      )

    GenServer.cast(Client, {:update_contact_clear_m_ratchet, message_data.sender_uuid})

    Logger.info("Decrypted message -> #{decrypted_message}")
  end
end
