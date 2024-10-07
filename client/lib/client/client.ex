defmodule Client do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def loop() do
    GenServer.cast(__MODULE__, {:set_loop_pid, self()})

    if System.get_env("USER") == "user1" do
      Process.sleep(1000)

      contact_uuid = Contact.add_contact("user2")
      #Client.Message.send("Hello, world!", contact_uuid)
      GenServer.cast(Client, {:send_message, "Hello World!", contact_uuid})

      Process.sleep(1000)

      #contact_uuid = Contact.add_contact("user2")
      #Client.Message.send("Hello, world!", contact_uuid)
      #else

      #  contact_uuid = Contact.add_contact("user1")
      #  Client.Message.send("Hello, world!", contact_uuid)

      #  Process.sleep(1000)

      #  contact_uuid = Contact.add_contact("user1")
      #  Client.Message.send("Hello, world!", contact_uuid)
    end

        Process.sleep(100000)
    #loop()
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  @spec handle_cast({:set_loop_pid, pid}, any) :: {:noreply, map}
  def handle_cast({:set_loop_pid, pid}, state) do
    pid = self()
    new_state = Map.put(state, "loop_pid", pid)

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:receive_message, binary}, any) :: {:noreply, map}
  def handle_cast({:receive_message, message_data}, state) do
    Client.Message.receive(message_data)

    {:noreply, state}
  end

  @impl true
  @spec handle_cast({:send_message, binary, binary}, any) :: {:noreply, map}
  def handle_cast({:send_message, message, recipient_uuid}, state) do
    Client.Message.send(message, recipient_uuid)

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_loop_pid}, _from, state) do
    {:reply, Map.get(state, "loop_pid"), state}
  end
end
