defmodule Client do
  use GenServer

  require Logger

  @type ratchet :: Crypt.Ratchet.ratchet()
  @type keypair :: Crypt.Keys.keypair()
  @type contact :: %{
          contact_id: binary,
          recipient_pub_key: binary,
          own_keypair: keypair,
          dh_ratchet: ratchet | nil,
          m_ratchet: ratchet | nil
        }

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    keypair = %{
      public: Base.decode16("08C9B85839F04E2A665A99B18018D3B54AB25F9C28D51420B6E378528C0DC459"),
      private: Base.decode16("DF2F4C61B99C25C96B55E1B5C2E04F419D8708248D196C177CF135F075ADFD60")
    }

    state = Map.put(state, "keypair", keypair)

    contact_uuid = ""

    state =
      Map.put(state, contact_uuid, %{
        contact_id: "wsl",
        recipient_pub_key: nil,
        own_keypair: keypair,
        dh_ratchet: nil,
        m_ratchet: nil
      })

    {:ok, state}
  end

  @impl true
  @spec handle_cast({:add_contact, binary, binary}, any) :: {:noreply, map}
  def handle_cast({:add_contact, contact_uuid, contact_id}, state) do
    keypair = Map.get(state, "keypair")

    GenServer.cast(TCPClient, {:send_data, :req_public_key, contact_uuid})

    new_state = state
    recipient_public_key = nil

    receive do
      {:public_key_response, response} ->
        recipient_public_key = response

        contact = Map.get(state, contact_uuid)
        new_contact = Map.put(contact, :recipient_pub_key, recipient_public_key)

        new_state = Map.put(new_state, contact_uuid, new_contact)

        Logger.info("Received public key: #{recipient_public_key}")

        {:reply, recipient_public_key, state}
    after
      5000 ->
        Logger.error("Timeout waiting for public key")
        exit(:timeout)
    end

    dh_ratchet = Crypt.Ratchet.rk_ratchet_init(keypair, recipient_public_key)

    contact = %{
      contact_id: contact_id,
      recipient_pub_key: nil,
      own_keypair: keypair,
      dh_ratchet: dh_ratchet,
      m_ratchet: nil
    }

    new_state = Map.put(new_state, contact_uuid, contact)
    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:update_contact_key, binary, binary}, any) :: {:noreply, map}
  def handle_cast({:update_contact_key, contact_uuid, key}, state) do
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
  def handle_cast({:update_contact_cycle, contact_uuid, keypair, dh_ratchet, m_ratchet}, state) do
    contact = Map.get(state, contact_uuid)

    new_contact = Map.put(contact, :own_keypair, keypair)
    new_contact = Map.put(new_contact, :dh_ratchet, dh_ratchet)
    new_contact = Map.put(new_contact, :m_ratchet, m_ratchet)

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
  @spec handle_call({:get_contact_uuid, binary}, any, map) :: {:reply, binary, map}
  def handle_call({:get_contact_uuid, contact_id}, _from, state) do
    contact_uuid =
      state
      |> Enum.find(fn {_, contact} -> contact.contact_id == contact_id end)
      |> elem(0)

    {:reply, contact_uuid, state}
  end

  @impl true
  @spec handle_call({:get_contact_key, binary}, any, map) :: {:reply, binary, map}
  def handle_call({:get_contact_key, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)

    recipient_public_key = contact.recipient_pub_key

    {:reply, recipient_public_key, state}
  end

  @impl true
  @spec handle_call({:get_contact_own_keypair, binary}, any, map) :: {:reply, keypair, map}
  def handle_call({:get_contact_own_keypair, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)

    {:reply, contact.own_keypair, state}
  end

  @impl true
  @spec handle_call({:get_contact_dh_ratchet, binary}, any, map) :: {:reply, ratchet, map}
  def handle_call({:get_contact_dh_ratchet, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)
    {:reply, contact.dh_ratchet, state}
  end

  @impl true
  @spec handle_call({:get_contact_m_ratchet, binary}, any, map) :: {:reply, ratchet, map}
  def handle_call({:get_contact_m_ratchet, contact_uuid}, _from, state) do
    contact = Map.get(state, contact_uuid)
    {:reply, contact.m_ratchet, state}
  end

  @impl true
  def handle_call({:get_pid}, _from, state) do
    {:reply, self(), state}
  end
end
