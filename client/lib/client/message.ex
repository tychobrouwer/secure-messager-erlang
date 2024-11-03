defmodule Client.Message do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

  @spec send(binary, binary) :: :ok
  def send(message, recipient_uuid) do
    Logger.notice("Sending message to #{inspect(recipient_uuid)}")

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

    result =
      GenServer.cast(TCPServer, {:send_data, :message, message_id, :erlang.term_to_binary(data)})

    Logger.notice("Message sent to #{inspect(recipient_uuid)}")

    result
  end

  @spec receive(binary) :: :ok
  def receive(message) do
    _message_data = %{
      sender_uuid: nil,
      recipient_uuid: nil,
      message_uuid: nil,
      tag: nil,
      hash: nil,
      public_key: nil,
      message: nil
    }

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
