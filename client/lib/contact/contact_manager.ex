defmodule ContactManager do
  use GenServer

  require Logger

  @type contact_state :: :receiving | :sending | nil
  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: %{
          contact_id: binary,
          contact_pub_key: binary,
          keypair: keypair,
          dh_ratchet: ratchet | nil,
          m_ratchet: ratchet | nil,
          state: contact_state
        }

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    keypair = Crypt.Keys.generate_keypair()

    state = Map.put(state, "keypair", keypair)
    state = Map.put(state, "pid", self())

    {:ok, state}
  end

  @impl true
  @spec handle_cast({:set_receive_pid, pid}, any) :: {:noreply, map}
  def handle_cast({:set_receive_pid, pid}, state) do
    new_state = Map.put(state, "receive_pid", pid)
    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:add_contact, binary, binary, binary}, any) :: {:noreply, map}
  def handle_cast({:add_contact, contact_uuid, contact_id, contact_pub_key}, state) do
    if Map.get(state, contact_uuid) != nil do
      Logger.error("Contact already exists")
      exit("Dont call add contact if it already exists")
    end

    keypair = Map.get(state, "keypair")

    dh_ratchet = Crypt.Ratchet.rk_ratchet_init(keypair, contact_pub_key)

    new_state =
      Map.put(state, contact_uuid, %{
        contact_id: contact_id,
        contact_pub_key: contact_pub_key,
        keypair: keypair,
        dh_ratchet: dh_ratchet,
        m_ratchet: nil,
        state: nil
      })

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:remove_contact, binary}, any) :: {:noreply, map}
  def handle_cast({:remove_contact, contact_uuid}, state) do
    new_state = Map.delete(state, contact_uuid)

    {:noreply, new_state}
  end

  @impl true
  @spec handle_call({:get_contact, binary}, any, map) :: {:reply, contact, map}
  def handle_call({:get_contact, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)

    {:reply, contact, state}
  end

  @impl true
  @spec handle_call({:cycle_contact_sending, binary}, any, map) ::
          {:reply, contact, map}
  def handle_call({:cycle_contact_sending, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)

    keypair =
      if contact.state != nil && contact.state != :sending do
        Crypt.Keys.generate_keypair()
      else
        contact.keypair
      end

    updated_contact = Map.put(contact, :keypair, keypair)

    contact_state = contact.state || :receiving

    case contact_state do
      :receiving ->
        dh_ratchet =
          Crypt.Ratchet.rk_cycle(
            updated_contact.dh_ratchet,
            updated_contact.keypair,
            updated_contact.contact_pub_key
          )

        m_ratchet = Crypt.Ratchet.ck_cycle(dh_ratchet.child_key)

        updated_contact = Map.put(updated_contact, :dh_ratchet, dh_ratchet)
        updated_contact = Map.put(updated_contact, :m_ratchet, m_ratchet)
        updated_contact = Map.put(updated_contact, :state, :sending)
        new_state = Map.put(state, contact_uuid, updated_contact)

        {:reply, updated_contact, new_state}

      :sending ->
        m_ratchet = Crypt.Ratchet.ck_cycle(updated_contact.m_ratchet.root_key)

        updated_contact = Map.put(updated_contact, :m_ratchet, m_ratchet)
        new_state = Map.put(state, contact_uuid, updated_contact)

        {:reply, updated_contact, new_state}
    end
  end

  @impl true
  @spec handle_call({:cycle_contact_receiving, binary, binary}, any, map) ::
          {:reply, contact, map}
  def handle_call({:cycle_contact_receiving, contact_uuid, pub_key}, _from, state) do
    contact = Map.get(state, contact_uuid)

    contact_state = contact.state || :sending

    updated_contact = Map.put(contact, :contact_pub_key, pub_key)

    case contact_state do
      :sending ->
        dh_ratchet =
          Crypt.Ratchet.rk_cycle(
            updated_contact.dh_ratchet,
            updated_contact.keypair,
            updated_contact.contact_pub_key
          )

        m_ratchet = Crypt.Ratchet.ck_cycle(dh_ratchet.child_key)

        updated_contact = Map.put(updated_contact, :dh_ratchet, dh_ratchet)
        updated_contact = Map.put(updated_contact, :m_ratchet, m_ratchet)
        updated_contact = Map.put(updated_contact, :state, :receiving)
        new_state = Map.put(state, contact_uuid, updated_contact)

        {:reply, updated_contact, new_state}

      :receiving ->
        m_ratchet = Crypt.Ratchet.ck_cycle(contact.m_ratchet.root_key)

        updated_contact = Map.put(updated_contact, :m_ratchet, m_ratchet)
        new_state = Map.put(state, contact_uuid, updated_contact)

        {:reply, updated_contact, new_state}
    end
  end

  @impl true
  @spec handle_call({:get_keypair}, any, map) :: {:reply, keypair, map}
  def handle_call({:get_keypair}, _from, state) do
    keypair = Map.get(state, "keypair")

    {:reply, keypair, state}
  end

  @impl true
  @spec handle_call({:get_receive_pid}, any, map) :: {:reply, pid, map}
  def handle_call({:get_receive_pid}, _from, state) do
    {:reply, Map.get(state, "receive_pid"), state}
  end
end
