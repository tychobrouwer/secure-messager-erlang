defmodule Contact do
  @moduledoc """

  """

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: ContactManager.contact()

  @spec add_contact(binary) :: binary
  def add_contact(contact_id) do
    contact_uuid = get_contact_uuid(contact_id)
    contact_pub_key = get_contact_pub_key(contact_uuid)

    GenServer.cast(ContactManager, {:add_contact, contact_uuid, contact_id, contact_pub_key})

    contact_uuid
  end

  @spec create_contact(binary, binary) :: binary
  def create_contact(contact_uuid, contact_pub_key) do
    contact_id = "temp"

    GenServer.cast(ContactManager, {:add_contact, contact_uuid, contact_id, contact_pub_key})

    contact_uuid
  end

  @spec get_contact_uuid(binary) :: binary
  def get_contact_uuid(contact_id) do
    GenServer.cast(TCPServer, {:send_data, :req_uuid, contact_id})

    receive do
      {:req_uuid_response, response} ->
        response
    after
      5000 ->
        Logger.warning("Timeout waiting for uuid")
        exit(:timeout)
    end
  end

  @spec get_contact_pub_key(binary) :: binary
  def get_contact_pub_key(contact_uuid) do
    GenServer.cast(TCPServer, {:send_data, :req_pub_key, contact_uuid})

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
