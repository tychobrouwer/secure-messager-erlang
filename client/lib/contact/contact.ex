defmodule Contact do
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
          contact_id = async_do(fn -> get_id(contact_uuid) end)

          {contact_id, contact_uuid}

        {contact_id, nil} ->
          contact_uuid = async_do(fn -> get_uuid(contact_id) end)

          {contact_id, contact_uuid}

        {contact_id, contact_uuid} ->
          {contact_id, contact_uuid}
      end

    if GenServer.call(ContactManager, {:get_contact, contact_uuid}) == nil do
      contact_pub_key = async_do(fn -> get_pub_key(contact_uuid) end)

      Utils.exit_on_nil(contact_pub_key, "add_contact")

      GenServer.cast(ContactManager, {:add_contact, contact_uuid, contact_id, contact_pub_key})
    end

    contact_uuid
  end

  @spec async_do(fun) :: any
  defp async_do(fun) do
    task =
      Task.async(fn ->
        GenServer.cast(ContactManager, {:set_receive_pid, self()})

        fun.()
      end)

    Task.await(task)
  end

  @spec get_uuid(binary) :: binary
  defp get_uuid(contact_id) do
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

  @spec get_id(binary) :: binary
  defp get_id(contact_uuid) do
    GenServer.cast(TCPServer, {:send_data, :req_id, contact_uuid})

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
