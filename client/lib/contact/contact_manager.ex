defmodule ContactManager do
  use GenServer

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: %{
          contact_id: binary,
          contact_pub_key: binary,
          own_keypair: keypair,
          dh_ratchet: ratchet | nil,
          m_ratchet: ratchet | nil
        }

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  state = %{
    loop_pid: pid,
    keypair: keypair,
    contact_uuid: contact
  }
  """

  @impl true
  def init(state) do
    keypair = %{
      public: Base.decode16!("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459"),
      private: Base.decode16!("DF2F4C61B99C25C96B55E1B5C2E04F419D8708248D196C177CF135F075ADFD60")
    }

    state = Map.put(state, "keypair", keypair)
    state = Map.put(state, "pid", self())

    {:ok, state}
  end

  @impl true
  @spec handle_cast({:set_loop_pid, pid}, any) :: {:noreply, map}
  def handle_cast({:set_loop_pid, pid}, state) do
    new_state = Map.put(state, "loop_pid", pid)

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:add_contact, binary, binary, binary}, any) :: {:noreply, map}
  def handle_cast({:add_contact, contact_uuid, contact_id, contact_pub_key}, state) do
    if Map.has_key?(state, contact_uuid) do
      Logger.warning("Contact already exists")

      {:noreply, state}
    end

    keypair = Map.get(state, "keypair")

    dh_ratchet = Crypt.Ratchet.rk_ratchet_init(keypair, contact_pub_key)

    new_state =
      Map.put(state, contact_uuid, %{
        contact_id: contact_id,
        contact_pub_key: contact_pub_key,
        own_keypair: keypair,
        dh_ratchet: dh_ratchet,
        m_ratchet: nil
      })

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:update_contact_pub_key, binary, binary}, any) :: {:noreply, map}
  def handle_cast({:update_contact_pub_key, contact_uuid, key}, state) do
    contact = Map.get(state, contact_uuid)
    new_contact = Map.put(contact, :recipient_pub_key, key)

    new_state = Map.put(state, contact_uuid, new_contact)

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:update_contact_own_keypair, binary, keypair}, any) ::
          {:noreply, map}
  def handle_cast({:update_contact_own_keypair, contact_uuid, keypair}, state) do
    contact = Map.get(state, contact_uuid)
    new_contact = Map.put(contact, :own_keypair, keypair)

    new_state = Map.put(state, contact_uuid, new_contact)

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:update_contact_cycle, binary, keypair, ratchet, ratchet}, any) ::
          {:noreply, map}
  def handle_cast(
        {:update_contact_cycle, contact_uuid, own_keypair, dh_ratchet, m_ratchet},
        state
      ) do
    contact = Map.get(state, contact_uuid)
    new_contact = Map.put(contact, :own_keypair, own_keypair)
    new_contact = Map.put(new_contact, :dh_ratchet, dh_ratchet)
    new_contact = Map.put(new_contact, :m_ratchet, m_ratchet)

    new_state = Map.put(state, contact_uuid, new_contact)

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:update_contact_clear_m_ratchet, binary}, any) :: {:noreply, map}
  def handle_cast({:update_contact_clear_m_ratchet, contact_uuid}, state) do
    contact = Map.get(state, contact_uuid)
    new_contact = Map.put(contact, :m_ratchet, nil)

    new_state = Map.put(state, contact_uuid, new_contact)

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:remove_contact, binary}, any) :: {:noreply, map}
  def handle_cast({:remove_contact, contact_uuid}, state) do
    new_state = Map.delete(state, contact_uuid)

    {:noreply, new_state}
  end

  @impl true
  @spec handle_call({:get_own_keypair}, any, map) :: {:reply, keypair, map}
  def handle_call({:get_own_keypair}, _from, state) do
    keypair = Map.get(state, "keypair")

    {:reply, keypair, state}
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

  @impl true
  @spec handle_call({:get_contact_pub_key, binary}, any, map) :: {:reply, binary, map}
  def handle_call({:get_contact_pub_key, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)

    if contact == nil do
      {:reply, nil, state}
    else
      contact_public_key = contact.contact_pub_key

      {:reply, contact_public_key, state}
    end
  end

  @impl true
  @spec handle_call({:get_contact_own_keypair, binary}, any, map) :: {:reply, keypair, map}
  def handle_call({:get_contact_own_keypair, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)

    if contact == nil do
      {:reply, Map.get(state, "keypair"), state}
    else
      {:reply, contact.own_keypair, state}
    end
  end

  @impl true
  @spec handle_call({:get_contact_dh_ratchet, binary}, any, map) :: {:reply, ratchet, map}
  def handle_call({:get_contact_dh_ratchet, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)

    if contact == nil do
      {:reply, nil, state}
    else
      {:reply, contact.dh_ratchet, state}
    end
  end

  @impl true
  @spec handle_call({:get_contact_m_ratchet, binary}, any, map) :: {:reply, ratchet, map}
  def handle_call({:get_contact_m_ratchet, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)

    if contact == nil do
      {:reply, nil, state}
    else
      {:reply, contact.m_ratchet, state}
    end
  end

  @impl true
  def handle_call({:get_pid}, _from, state) do
    {:reply, Map.get(state, "pid"), state}
  end
end
