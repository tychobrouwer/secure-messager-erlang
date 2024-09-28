defmodule ClientTester do
  use ExUnit.Case, async: true

  doctest Client
  doctest Client.DHKeys

  require Logger

  test "client" do
    uuid = "273ffb373a0eaa9d04af09c6930cd0cfc1091117"

    GenServer.cast(Client, {:add_contact, uuid, "user1"})

    contact_uuid = GenServer.call(Client, {:get_contact_uuid, "user1"})
    contact = GenServer.call(Client, {:get_contact, contact_uuid})

    assert contact_uuid == uuid
    assert contact == %{contact_id: "user1", key_data: []}

    GenServer.cast(Client, {:add_contact_key, uuid, "key_data"})

    contact = GenServer.call(Client, {:get_contact, contact_uuid})

    assert contact == %{contact_id: "user1", key_data: ["key_data"]}

    GenServer.cast(Client, {:remove_contact, uuid})

    contact = GenServer.call(Client, {:get_contact, contact_uuid})

    assert contact == nil
  end
end
