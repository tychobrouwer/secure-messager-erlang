defmodule Client do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_loop()

    {:ok, state}
  end

  @impl true
  def handle_info(:loop, state) do
    loop()
    schedule_loop()

    {:noreply, state}
  end

  defp schedule_loop() do
    send(self(), :loop)
    # Process.send_after(self(), :loop, 100_000)
  end

  defp loop() do
    if System.get_env("USER") == "user1" do
      Process.sleep(1000)

      contact_uuid = Contact.add_contact(nil, "user2")
      Client.Message.send("Hello World! 1", contact_uuid)

      Process.sleep(1000)

      Client.Message.send("Hello World! 2", contact_uuid)

      Process.sleep(1000)

      Client.Message.send("Hello World! 3", contact_uuid)
    end

    if System.get_env("USER") == "user2" do
      Process.sleep(6000)

      contact_uuid = Contact.add_contact(nil, "user1")
      Client.Message.send("Hello World! 4", contact_uuid)

      Process.sleep(1000)

      Client.Message.send("Hello World! 5", contact_uuid)

      Process.sleep(1000)

      Client.Message.send("Hello World! 6", contact_uuid)
    end

    Process.sleep(5000)
  end
end
