defmodule Client.Contact do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

  @spec add_contact(binary | nil, binary | nil) :: binary
  def add_contact(contact_uuid, contact_id) do
    Logger.notice("Adding contact with uuid: #{contact_uuid} and id: #{contact_id}")

    {contact_uuid, contact_id} =
      case {contact_uuid, contact_id} do
        {nil, nil} ->
          Logger.error("No contact id or uuid provided")
          exit("Dont call add contact if id and uuid are nil")

        {contact_uuid, nil} ->
          message_id = GenServer.call(TCPServer, {:get_message_id})

          contact_id =
            TCPServer.async_receive(fn -> get_id(contact_uuid, message_id) end, message_id)

          {contact_uuid, contact_id}

        {nil, contact_id} ->
          contact_id_hash = :crypto.hash(:md4, contact_id)
          message_id = GenServer.call(TCPServer, {:get_message_id})

          contact_uuid =
            TCPServer.async_receive(fn -> get_uuid(contact_id_hash, message_id) end, message_id)

          {contact_uuid, contact_id}

        {contact_uuid, contact_id} ->
          {contact_uuid, contact_id}
      end

    if GenServer.call(ContactManager, {:get_contact, contact_uuid}) == nil do
      message_id = GenServer.call(TCPServer, {:get_message_id})

      contact_pub_key =
        TCPServer.async_receive(fn -> get_pub_key(contact_uuid, message_id) end, message_id)

      GenServer.cast(ContactManager, {:add_contact, contact_uuid, contact_id, contact_pub_key})
    end

    Logger.notice("Contact added with uuid: #{contact_uuid} and id: #{contact_id}")

    contact_uuid
  end

  defp get_uuid(contact_id_hash, message_id) do
    GenServer.cast(TCPServer, {:send_data, :req_uuid, message_id, contact_id_hash, :with_auth})

    receive do
      {:req_uuid_response, response} ->
        response
    after
      5000 ->
        Logger.warning("Timeout waiting for uuid")
        exit(:timeout)
    end
  end

  defp get_id(contact_uuid, message_id) do
    GenServer.cast(TCPServer, {:send_data, :req_id, message_id, contact_uuid, :with_auth})

    receive do
      {:req_id_response, response} ->
        response
    after
      5000 ->
        Logger.warning("Timeout waiting for id")
        exit(:timeout)
    end
  end

  defp get_pub_key(contact_uuid, message_id) do
    GenServer.cast(TCPServer, {:send_data, :req_pub_key, message_id, contact_uuid, :with_auth})

    receive do
      {:req_pub_key_response, response} ->
        response
    after
      5000 ->
        Logger.warning("Timeout waiting for public key")
        exit(:timeout)
    end
  end
end
