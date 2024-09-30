defmodule Client.Contact do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: Client.contact()

  def add_contact(contact_id) do
    contact_uuid = get_contact_uuid(contact_id)
    contact_pub_key = get_contact_pub_key(contact_uuid)

    GenServer.cast(Client, {:add_contact, contact_uuid, contact_id, contact_pub_key})

    contact_uuid
  end

  def get_contact_uuid(contact_id) do
    GenServer.call(TCPServer, {:send_data, :req_uuid, contact_id})

    receive do
      {:req_uuid_response, response} ->
        response
    after
      5000 ->
        Logger.warn("Timeout waiting for public key")
        exit(:timeout)
    end
  end

  def get_contact_pub_key(contact_uuid) do
    GenServer.call(TCPServer, {:send_data, :req_pub_key, contact_uuid})

    receive do
      {:req_pub_key_response, response} ->
        response
    after
      5000 ->
        Logger.warn("Timeout waiting for public key")
        exit(:timeout)
    end
  end
end
