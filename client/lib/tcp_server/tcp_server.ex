defmodule TCPServer do
  use GenServer

  alias TCPServer.Utils, as: Utils

  defguardp verify_bin(binary, length)
            when binary != nil and is_binary(binary) and byte_size(binary) == length

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:set_uuid, uuid}, state) when verify_bin(uuid, 20) do
    new_state = Map.put(state, "uuid", uuid)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:add_connection, pid}, state) when is_pid(pid) do
    new_state = Map.put(state, "tcp_pid", pid)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_connection}, state) do
    new_state = Map.delete(state, "tcp_pid")
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:send_data, type, message_id, data}, state) do
    pid = Map.get(state, "tcp_pid")
    auth = Utils.get_packet_response_type(type)

    send(pid, {:send_data, type, message_id, data, auth})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_receive_pid, message_id, pid}, state) when is_pid(pid) do
    new_state = Map.put(state, message_id, pid)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_receive_pid, message_id}, state) do
    new_state = Map.delete(state, message_id)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:set_auth_token, token}, state) when verify_bin(token, 29) do
    {:noreply, Map.put(state, :auth_token, token)}
  end

  @impl true
  def handle_cast({:set_auth_id, id}, state) when verify_bin(id, 16) do
    {:noreply, Map.put(state, :auth_id, id)}
  end

  @impl true
  def handle_call({:get_auth_token}, _from, state) do
    {:reply, Map.get(state, :auth_token), state}
  end

  @impl true
  def handle_call({:get_auth_id}, _from, state) do
    {:reply, Map.get(state, :auth_id), state}
  end

  @impl true
  def handle_call({:get_message_id}, _from, state) do
    auth_id = Map.get(state, :auth_id)
    perf_counter = :os.perf_counter()

    if auth_id == nil do
      {:reply, :crypto.hash(:md4, <<perf_counter::64>>), state}
    else
      {:reply, :crypto.hash(:md4, <<perf_counter::64, auth_id::binary>>), state}
    end
  end

  @impl true
  def handle_call({:get_uuid}, _from, state) do
    {:reply, Map.get(state, "uuid"), state}
  end

  @impl true
  def handle_call({:get_connection_pid}, _from, state) do
    {:reply, Map.get(state, "tcp_pid"), state}
  end

  @impl true
  def handle_call({:get_receive_pid, message_id}, _from, state) do
    {:reply, Map.get(state, message_id), state}
  end

  def get_async_server_value(req_type, message_id, data) do
    task =
      Task.async(fn ->
        GenServer.cast(TCPServer, {:set_receive_pid, message_id, self()})
        GenServer.cast(TCPServer, {:send_data, req_type, message_id, data})

        receive do
          {:req_response, response} ->
            response

          {:req_error_response, reason} ->
            Logger.error("Error getting #{req_type} value: #{reason}")
        after
          5000 ->
            Logger.error("Timeout waiting for #{req_type} value")
            exit(:timeout)
        end
      end)

    result = Task.await(task)

    GenServer.cast(TCPServer, {:remove_receive_pid, message_id})

    result
  end
end
