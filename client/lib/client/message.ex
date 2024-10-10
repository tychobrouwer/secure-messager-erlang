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
    contact = GenServer.call(ContactManager, {:cycle_contact_sending, recipient_uuid})

    {encrypted_message, message_tag, mac_hash} =
      Crypt.Message.encrypt(message, contact.m_ratchet.child_key)

    data = %{
      sender_uuid: GenServer.call(TCPServer, {:get_uuid}),
      recipient_uuid: recipient_uuid,
      message_uuid: Client.Utils.uuid(),
      tag: message_tag,
      hash: mac_hash,
      public_key: contact.keypair.public,
      message: encrypted_message
    }

    GenServer.cast(TCPServer, {:send_data, :message, :erlang.term_to_binary(data)})
  end

  @spec receive(binary) :: :ok
  def receive(message) do
    message_data = :erlang.binary_to_term(message)

    sender_uuid = message_data.sender_uuid

    contact = GenServer.call(ContactManager, {:get_contact, sender_uuid})

    if contact == nil do
      Contact.add_contact(sender_uuid, nil)
    end

    contact =
      GenServer.call(
        ContactManager,
        {:cycle_contact_receiving, sender_uuid, message_data.public_key}
      )

    {decrypted_message, valid} =
      Crypt.Message.decrypt(
        message_data.message,
        message_data.tag,
        message_data.hash,
        contact.m_ratchet.child_key
      )

    Logger.info("Decrypted message -> #{valid} : #{decrypted_message}")
  end
end
