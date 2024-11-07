defmodule Client.Message do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

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

    message_id = GenServer.call(TCPServer, {:get_message_id})

    case TCPServer.send_receive_data(:message, message_id, :erlang.term_to_binary(data)) do
      {:error, reason} ->
        Logger.error("Failed to send message to #{inspect(recipient_uuid)}, reason: #{reason}")

        exit("Failed to send message")

      result ->
        Logger.notice("Message sent to #{inspect(recipient_uuid)}")

        result
    end
  end

  def receive(message) do
    message_data = :erlang.binary_to_term(message, [:safe])

    contact = GenServer.call(ContactManager, {:get_contact, message_data.sender_uuid})

    if contact == nil do
      Client.Contact.add_contact(message_data.sender_uuid, nil)
    end

    contact =
      GenServer.call(
        ContactManager,
        {:cycle_contact_receiving, message_data.sender_uuid, message_data.public_key}
      )

    {decrypted_message, valid} =
      Crypt.Message.decrypt(
        message_data.message,
        message_data.tag,
        message_data.hash,
        contact.m_ratchet.child_key
      )

    Logger.notice("Decrypted message -> #{valid} : #{decrypted_message}")
  end
end
