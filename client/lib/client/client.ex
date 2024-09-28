defmodule Client do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_contact, contact_uuid, contact_id}, state) do
    contact = %{contact_id: contact_id, key_data: []}

    new_state = Map.put(state, contact_uuid, contact)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:add_contact_key, contact_uuid, key_data}, state) do
    contact = Map.get(state, contact_uuid)

    new_contact = Map.update!(contact, :key_data, fn keys -> keys ++ [key_data] end)

    new_state = Map.put(state, contact_uuid, new_contact)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_contact, contact_uuid}, state) do
    new_state = Map.delete(state, contact_uuid)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_contact, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)
    {:reply, contact, state}
  end

  @impl true
  @spec handle_call({:get_contact_uuid, binary}, any, map) :: {:reply, binary, map}
  def handle_call({:get_contact_uuid, contact_id}, _from, state) do
    contact_uuid =
      state
      |> Enum.find(fn {_, contact} -> contact.contact_id == contact_id end)
      |> elem(0)

    {:reply, contact_uuid, state}
  end
end
