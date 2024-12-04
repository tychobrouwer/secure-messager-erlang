defmodule Client.Message do
  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

  def send(message, receiver_id_hash) do
    contact = GenServer.call(ContactManager, {:cycle_contact_sending, receiver_id_hash})

    {encrypted_message, message_tag, mac_hash} =
      Crypt.Message.encrypt(message, contact.m_ratchet.child_key)

    data = %{
      sender_id_hash: GenServer.call(TCPServer, {:get_auth_id}),
      receiver_id_hash: receiver_id_hash,
      tag: message_tag,
      hash: mac_hash,
      public_key: contact.keypair.public,
      message: encrypted_message
    }

    message_id = GenServer.call(TCPServer, {:get_message_id})

    case TCPServer.send_receive_data(:message, message_id, :erlang.term_to_binary(data)) do
      {:error, reason} ->
        Logger.error("Failed to send message to #{inspect(receiver_id_hash)}, reason: #{reason}")

        exit("Failed to send message")

      _result ->
        Logger.notice("Message sent to #{inspect(receiver_id_hash)}")

        true
    end
  end

  def request_new() do
    message_id = GenServer.call(TCPServer, {:get_message_id})

    last_update_timestamp_us = GenServer.call(ContactManager, {:last_update_timestamp})
    data = :erlang.integer_to_binary(last_update_timestamp_us)

    case TCPServer.send_receive_data(:req_messages, message_id, data) do
      {:error, reason} ->
        Logger.error("Failed to request new messages")

        exit("Failed to request new messages")

      messages ->
        Logger.notice("Messages received from #{inspect(receiver_id_hash)}")

        receive_array(messages)
    end
  end

  def receive_array(messages) do
    messages_data = :erlang.binary_to_term(messages, [:safe])

    Enum.each(messages_data, fn message_data ->
      contact = GenServer.call(ContactManager, {:get_contact, message_data.sender_id_hash})

      if contact == nil do
        Client.Contact.add_contact(message_data.sender_id_hash)
      end

      contact =
        GenServer.call(
          ContactManager,
          {:cycle_contact_receiving, message_data.sender_id_hash, message_data.public_key}
        )

      {decrypted_message, valid} =
        Crypt.Message.decrypt(
          message_data.message,
          message_data.tag,
          message_data.hash,
          contact.m_ratchet.child_key
        )

      Logger.notice("Decrypted message -> #{valid} : #{decrypted_message}")
    end)
  end
end
