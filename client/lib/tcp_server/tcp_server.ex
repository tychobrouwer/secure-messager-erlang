defmodule TCPServer do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:set_uuid, uuid}, state) do
    new_state = Map.put(state, "uuid", uuid)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:add_connection, pid}, state) do
    new_state = Map.put(state, "tcp_pid", pid)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_connection}, state) do
    new_state = Map.delete(state, "tcp_pid")
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:send_data, type, data}, state) do
    pid = Map.get(state, "tcp_pid")

    send(pid, {:send_data, type, data})
    {:noreply, state}
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
  def handle_call({:get_pid}, _from, state) do
    {:reply, self(), state}
  end
end
