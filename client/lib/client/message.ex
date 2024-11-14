defmodule Client.Message do
  @moduledoc """

  """

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

  def receive(message) do
    message_data = :erlang.binary_to_term(message, [:safe])

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
  end
end

# data = %{
#   sender_id_hash: <<0>>,
#   receiver_id_hash: <<0>>,
#   tag: <<0>>,
#   hash: <<0>>,
#   public_key: <<0>>,
#   message: <<0>>
# }
