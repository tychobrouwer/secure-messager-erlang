defmodule ClientTester do
  use ExUnit.Case, async: true

  doctest Client

  require Logger

  test "client" do
    uuid =
      <<24, 65, 241, 190, 166, 108, 241, 141, 216, 86, 73, 1, 223, 247, 96, 100, 16, 38, 230, 75,
        119, 115, 108>>

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
