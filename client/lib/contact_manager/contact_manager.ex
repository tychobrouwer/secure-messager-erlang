defmodule ContactManager do
  use GenServer

  require Logger

  defguardp verify_bin(binary, length)
            when binary != nil and is_binary(binary) and byte_size(binary) == length

  @type contact_state :: :receiving | :sending | nil
  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: %{
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
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_contact, contact_id_hash, contact_pub_key}, state)
      when verify_bin(contact_id_hash, 16) and verify_bin(contact_pub_key, 32) do
    if Map.get(state, contact_id_hash) != nil do
      Logger.error("Contact already exists")

      exit("Dont call add contact if it already exists")
    end

    keypair = Map.get(state, "keypair")

    dh_ratchet = Crypt.Ratchet.rk_ratchet_init(keypair, contact_pub_key)

    new_state =
      Map.put(state, contact_id_hash, %{
        contact_pub_key: contact_pub_key,
        keypair: keypair,
        dh_ratchet: dh_ratchet,
        m_ratchet: nil,
        state: nil
      })

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_contact, contact_id_hash}, state)
      when verify_bin(contact_id_hash, 16) do
    new_state = Map.delete(state, contact_id_hash)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(request, state) do
    Logger.error("Unknown cast request contact_manager -> #{inspect(request)}")

    {:noreply, state}
  end

  @impl true
  def handle_call({:last_update_timestamp}, _from, state) do
    last_update_timestamp = Map.get(state, "last_update_timestamp")

    current_timestamp_us = System.os_time(:microsecond)
    new_state = Map.put(state, "last_update_timestamp", current_timestamp_us)

    case last_update_timestamp do
      nil ->
        {:reply, 0, new_state}

      _ ->
        {:reply, last_update_timestamp, new_state}
    end
  end

  @impl true
  def handle_call({:get_contact, contact_id_hash}, _from, state)
      when verify_bin(contact_id_hash, 16) do
    contact = Map.get(state, contact_id_hash)

    {:reply, contact, state}
  end

  @impl true
  def handle_call({:cycle_contact_sending, contact_id_hash}, _from, state)
      when verify_bin(contact_id_hash, 16) do
    contact = Map.get(state, contact_id_hash)

    if contact == nil do
      Logger.error("Contact not found")

      exit("Dont call cycle contact sending if contact not found")
    end

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
        new_state = Map.put(state, contact_id_hash, updated_contact)

        {:reply, updated_contact, new_state}

      :sending ->
        m_ratchet = Crypt.Ratchet.ck_cycle(updated_contact.m_ratchet.root_key)

        updated_contact = Map.put(updated_contact, :m_ratchet, m_ratchet)
        new_state = Map.put(state, contact_id_hash, updated_contact)

        {:reply, updated_contact, new_state}
    end
  end

  @impl true
  def handle_call({:cycle_contact_receiving, contact_id_hash, pub_key}, _from, state)
      when verify_bin(contact_id_hash, 16) and verify_bin(pub_key, 32) do
    contact = Map.get(state, contact_id_hash)

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
        new_state = Map.put(state, contact_id_hash, updated_contact)

        {:reply, updated_contact, new_state}

      :receiving ->
        m_ratchet = Crypt.Ratchet.ck_cycle(contact.m_ratchet.root_key)

        updated_contact = Map.put(updated_contact, :m_ratchet, m_ratchet)
        new_state = Map.put(state, contact_id_hash, updated_contact)

        {:reply, updated_contact, new_state}
    end
  end

  @impl true
  def handle_call({:generate_keypair}, _from, state) do
    # keypair = Crypt.Keys.generate_keypair()
    keypair = %{
      public:
        <<127, 172, 209, 228, 158, 231, 246, 100, 228, 45, 149, 194, 186, 61, 162, 91, 142, 106,
          25, 227, 127, 233, 133, 94, 159, 61, 169, 49, 142, 34, 122, 100>>,
      private:
        <<248, 16, 166, 102, 149, 67, 173, 100, 83, 230, 198, 40, 85, 168, 147, 255, 190, 173,
          255, 139, 240, 189, 93, 177, 6, 154, 105, 94, 154, 155, 160, 92>>
    }

    new_state = Map.put(state, "keypair", keypair)

    {:reply, keypair.public, new_state}
  end

  @impl true
  def handle_call({:get_keypair}, _from, state) do
    keypair = Map.get(state, "keypair")

    {:reply, keypair, state}
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.error("Unknown call request contact_manager -> #{inspect(request)}")

    {:reply, nil, state}
  end
end
