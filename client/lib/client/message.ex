defmodule Client.Message do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

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
    keypair = GenServer.call(ContactManager, {:get_contact_own_keypair, recipient_uuid})
    dh_ratchet = GenServer.call(ContactManager, {:get_contact_dh_ratchet, recipient_uuid})
    m_ratchet = GenServer.call(ContactManager, {:get_contact_m_ratchet, recipient_uuid})

    {dh_ratchet, m_ratchet, keypair} =
      if m_ratchet == nil do
        recipient_public_key = Contact.get_contact_pub_key(recipient_uuid)

        keypair = Crypt.Keys.generate_keypair()

        #GenServer.cast(TCPServer, {:send_data, :req_update_pub_key, keypair.public})

        Logger.info("dh_ratchet: \"#{inspect(dh_ratchet)}\"")

        dh_ratchet = Crypt.Ratchet.rk_cycle(dh_ratchet, keypair, recipient_public_key)
        m_ratchet = Crypt.Ratchet.ck_cycle(dh_ratchet.child_key)

        {dh_ratchet, m_ratchet, keypair}
      else
        m_ratchet = Crypt.Ratchet.ck_cycle(m_ratchet.root_key)

        {dh_ratchet, m_ratchet, keypair}
      end

    GenServer.cast(
      ContactManager,
      {:update_contact_cycle, recipient_uuid, keypair, dh_ratchet, m_ratchet}
    )

    {encrypted_message, message_tag, mac_hash} = Crypt.Message.encrypt(message, m_ratchet.child_key)

    data = %{
      sender_uuid: GenServer.call(TCPServer, {:get_uuid}),
      recipient_uuid: recipient_uuid,
      message_uuid: Client.Utils.uuid(),
      tag: message_tag,
      hash: mac_hash,
      public_key: keypair.public,
      message: encrypted_message
    }

    GenServer.cast(TCPServer, {:send_data, :message, :erlang.term_to_binary(data)})
  end

  @spec receive(binary) :: :ok
  def receive(message) do
    message_data = :erlang.binary_to_term(message)

    sender_uuid = message_data.sender_uuid

    Contact.add_contact_with_uuid(sender_uuid)

    keypair = GenServer.call(ContactManager, {:get_contact_own_keypair, sender_uuid})
    dh_ratchet = GenServer.call(ContactManager, {:get_contact_dh_ratchet, sender_uuid})
    m_ratchet = GenServer.call(ContactManager, {:get_contact_m_ratchet, sender_uuid})

    last_pub_key = GenServer.call(ContactManager, {:get_contact_pub_key, sender_uuid}) 

    {dh_ratchet, m_ratchet} =
      if m_ratchet == nil || last_pub_key != message_data.public_key do
        GenServer.cast(TCPServer, {:send_data, :req_update_pub_key, keypair.public})

        Logger.info("dh_ratchet: \"#{inspect(dh_ratchet)}\"")

        dh_ratchet = Crypt.Ratchet.rk_cycle(dh_ratchet, keypair, message_data.public_key)
        m_ratchet = Crypt.Ratchet.ck_cycle(dh_ratchet.child_key)

        {dh_ratchet, m_ratchet}
      else
        m_ratchet = Crypt.Ratchet.ck_cycle(m_ratchet.root_key)

        {dh_ratchet, m_ratchet}
      end

    GenServer.cast(
      ContactManager,
      {:update_contact_cycle, sender_uuid, keypair, dh_ratchet, m_ratchet}
    )

    {decrypted_message, valid} =
      Crypt.Message.decrypt(
        message_data.message,
        message_data.tag,
        message_data.hash,
        m_ratchet.child_key
      )

    Logger.info("Decrypted message -> #{valid} : #{decrypted_message}")
  end
end
