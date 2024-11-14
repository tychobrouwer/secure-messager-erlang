defmodule Client.Contact do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

  def add_contact(contact_id_hash) do
    if GenServer.call(ContactManager, {:get_contact, contact_id_hash}) == nil do
      message_id = GenServer.call(TCPServer, {:get_message_id})

      case TCPServer.send_receive_data(:req_pub_key, message_id, contact_id_hash) do
        {:error, reason} ->
          Logger.error(
            "Failed to get contact public key for contact uuid: #{contact_id_hash}, reason: #{reason}"
          )

          exit("Failed to get contact public key")

        contact_pub_key ->
          GenServer.cast(
            ContactManager,
            {:add_contact, contact_id_hash, contact_pub_key}
          )
      end
    end

    Logger.notice("Contact added with id: #{inspect(contact_id_hash)}")
  end
end
