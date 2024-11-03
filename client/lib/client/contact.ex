defmodule Client.Contact do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

  @spec add_contact(binary | nil, binary | nil) :: binary
  def add_contact(contact_uuid, contact_id) do
    Logger.notice("Adding contact with id: #{contact_id}")

    {contact_uuid, contact_id} =
      case {contact_uuid, contact_id} do
        {nil, nil} ->
          Logger.error("No contact id or uuid provided")
          exit("Dont call add contact if id and uuid are nil")

        {contact_uuid, nil} ->
          message_id = GenServer.call(TCPServer, {:get_message_id})

          contact_id =
            TCPServer.get_async_server_value(:req_id, message_id, contact_uuid)

          {contact_uuid, contact_id}

        {nil, contact_id} ->
          contact_id_hash = :crypto.hash(:md4, contact_id)
          message_id = GenServer.call(TCPServer, {:get_message_id})

          contact_uuid =
            TCPServer.get_async_server_value(:req_uuid, message_id, contact_id_hash)

          {contact_uuid, contact_id}

        {contact_uuid, contact_id} ->
          {contact_uuid, contact_id}
      end

    if GenServer.call(ContactManager, {:get_contact, contact_uuid}) == nil do
      message_id = GenServer.call(TCPServer, {:get_message_id})

      contact_pub_key =
        TCPServer.get_async_server_value(:req_pub_key, message_id, contact_uuid)

      GenServer.cast(ContactManager, {:add_contact, contact_uuid, contact_id, contact_pub_key})
    end

    Logger.notice("Contact added with id: #{inspect(contact_id)}")

    contact_uuid
  end
end
