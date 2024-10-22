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
    user_id = System.get_env("USER")
    user_password = "password123"

    token = Client.Account.signup(user_id, user_password)

    nil_token = <<0::size(29 * 8)>>

    token =
      if token == nil_token do
        token = Client.Account.login(user_id, user_password)

        if token == nil_token do
          Logger.error("Login failed")
          exit("Login failed")
        end

        Logger.info("Login successful: #{user_id}")

        token
      else
        Logger.info("Signup successful: #{user_id}")

        token
      end

    user_id_hash = :crypto.hash(:md4, user_id)
    GenServer.cast(TCPServer, {:set_auth_token, token})
    GenServer.cast(TCPServer, {:set_auth_id, user_id_hash})

    if user_id == "user1" do
      Process.sleep(1000)

      contact_uuid = Client.Contact.add_contact(nil, "user2")

      Client.Message.send("Hello World! 1", contact_uuid)
      Process.sleep(1000)
      Client.Message.send("Hello World! 2", contact_uuid)
      Process.sleep(1000)
      Client.Message.send("Hello World! 3", contact_uuid)
    end

    if user_id == "user2" do
      Process.sleep(6000)

      contact_uuid = Client.Contact.add_contact(nil, "user1")

      Client.Message.send("Hello World! 4", contact_uuid)
      Process.sleep(1000)
      Client.Message.send("Hello World! 5", contact_uuid)
      Process.sleep(1000)
      Client.Message.send("Hello World! 6", contact_uuid)
    end

    Process.sleep(6000)
  end
end
