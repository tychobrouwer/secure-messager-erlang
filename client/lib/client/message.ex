defmodule Client.Message do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

  @spec send(binary, binary) :: :ok
  def send(message, recipient_uuid) do
    contact = GenServer.call(ContactManager, {:cycle_contact_sending, recipient_uuid})

    Utils.exit_on_nil(contact, "send")
    Utils.exit_on_nil(contact.m_ratchet, "send")
    Utils.exit_on_nil(contact.m_ratchet.child_key, "send")
    Utils.exit_on_nil(contact.keypair.public, "send")

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

    GenServer.cast(TCPServer, {:send_data, :message, :erlang.term_to_binary(data), :with_auth})
  end

  @spec receive(binary) :: :ok
  def receive(message) do
    message_data = :erlang.binary_to_term(message)

    Utils.exit_on_nil(message_data.sender_uuid, "receive")
    Utils.exit_on_nil(message_data.recipient_uuid, "receive")
    Utils.exit_on_nil(message_data.message_uuid, "receive")
    Utils.exit_on_nil(message_data.tag, "receive")
    Utils.exit_on_nil(message_data.hash, "receive")
    Utils.exit_on_nil(message_data.public_key, "receive")
    Utils.exit_on_nil(message_data.message, "receive")

    contact = GenServer.call(ContactManager, {:get_contact, message_data.sender_uuid})

    if contact == nil do
      Client.Contact.add_contact(message_data.sender_uuid, nil)
    end

    contact =
      GenServer.call(
        ContactManager,
        {:cycle_contact_receiving, message_data.sender_uuid, message_data.public_key}
      )

    Utils.exit_on_nil(contact.m_ratchet, "send")
    Utils.exit_on_nil(contact.m_ratchet.child_key, "send")

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
