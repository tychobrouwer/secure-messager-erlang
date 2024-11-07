defmodule Client.Contact do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

  def add_contact(contact_uuid, contact_id) do
    {contact_uuid, contact_id} =
      case {contact_uuid, contact_id} do
        {nil, nil} ->
          Logger.error("No contact id or uuid provided")
          exit("Dont call add contact if id and uuid are nil")

        {contact_uuid, nil} ->
          message_id = GenServer.call(TCPServer, {:get_message_id})

          case TCPServer.send_receive_data(:req_id, message_id, contact_uuid) do
            {:error, reason} ->
              Logger.error(
                "Failed to get contact id for contact uuid: #{contact_uuid}, reason: #{reason}"
              )

              exit("Failed to get contact id")

            contact_id ->
              {contact_uuid, contact_id}
          end

        {nil, contact_id} ->
          contact_id_hash = :crypto.hash(:sha, contact_id)
          message_id = GenServer.call(TCPServer, {:get_message_id})

          case TCPServer.send_receive_data(:req_uuid, message_id, contact_id_hash) do
            {:error, reason} ->
              Logger.error(
                "Failed to get contact uuid for contact id: #{contact_id}, reason: #{reason}"
              )

              exit("Failed to get contact uuid")

            contact_uuid ->
              {contact_uuid, contact_id}
          end

        {contact_uuid, contact_id} ->
          {contact_uuid, contact_id}
      end

    if GenServer.call(ContactManager, {:get_contact, contact_uuid}) == nil do
      message_id = GenServer.call(TCPServer, {:get_message_id})

      case TCPServer.send_receive_data(:req_pub_key, message_id, contact_uuid) do
        {:error, reason} ->
          Logger.error(
            "Failed to get contact public key for contact uuid: #{contact_uuid}, reason: #{reason}"
          )

          exit("Failed to get contact public key")

        contact_pub_key ->
          GenServer.cast(
            ContactManager,
            {:add_contact, contact_uuid, contact_id, contact_pub_key}
          )
      end
    end

    Logger.notice("Contact added with id: #{inspect(contact_id)}")

    contact_uuid
  end
end
