defmodule Client.Contact do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

  @spec add_contact(binary | nil, binary | nil) :: binary
  def add_contact(contact_uuid, contact_id) do
    {contact_id, contact_uuid} =
      case {contact_id, contact_uuid} do
        {nil, nil} ->
          Logger.error("No contact id or uuid provided")
          exit("Dont call add contact if id and uuid are nil")

        {nil, contact_uuid} ->
          contact_id = TCPServer.async_do(fn -> get_id(contact_uuid) end)

          {contact_id, contact_uuid}

        {contact_id, nil} ->
          contact_id_hash = :crypto.hash(:md4, contact_id)
          contact_uuid = TCPServer.async_do(fn -> get_uuid(contact_id_hash) end)

          {contact_id, contact_uuid}

        {contact_id, contact_uuid} ->
          {contact_id, contact_uuid}
      end

    if GenServer.call(ContactManager, {:get_contact, contact_uuid}) == nil do
      contact_pub_key = TCPServer.async_do(fn -> get_pub_key(contact_uuid) end)

      GenServer.cast(ContactManager, {:add_contact, contact_uuid, contact_id, contact_pub_key})
    end

    contact_uuid
  end

  @spec get_uuid(binary) :: binary
  defp get_uuid(contact_id_hash) do
    GenServer.cast(TCPServer, {:send_data, :req_uuid, contact_id_hash, :with_auth})

    receive do
      {:req_uuid_response, response} ->
        response
    after
      5000 ->
        Logger.warning("Timeout waiting for uuid")
        exit(:timeout)
    end
  end

  @spec get_id(binary) :: binary
  defp get_id(contact_uuid) do
    GenServer.cast(TCPServer, {:send_data, :req_id, contact_uuid, :with_auth})

    receive do
      {:req_id_response, response} ->
        response
    after
      5000 ->
        Logger.warning("Timeout waiting for id")
        exit(:timeout)
    end
  end

  @spec get_pub_key(binary) :: binary
  defp get_pub_key(contact_uuid) do
    GenServer.cast(TCPServer, {:send_data, :req_pub_key, contact_uuid, :with_auth})

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
