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

    add_contact_with_uuid(contact_uuid, contact_id)
  end

  @spec add_contact_with_uuid(binary) :: binary
  def add_contact_with_uuid(contact_uuid, contact_id \\ "") do
    if !GenServer.call(ContactManager, {:check_contact_exists, contact_uuid}) do
      Logger.info("contact_uuid: #{inspect(contact_uuid)}")

      contact_pub_key = get_contact_pub_key(contact_uuid)
      
      Logger.info("contact_uuid: #{inspect(contact_pub_key)}")

      GenServer.cast(ContactManager, {:add_contact, contact_uuid, contact_id, contact_pub_key})
    end

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
    Logger.info("before sendsendsendsend")
    GenServer.cast(TCPServer, {:send_data, :req_pub_key, contact_uuid})
    
    Logger.info("sendsendsendsend")

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
