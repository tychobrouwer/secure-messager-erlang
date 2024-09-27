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
  def handle_cast({:add_connection, pid}, state) do
    new_state = Map.put(state, 'tcp_pid', pid)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_connection}, state) do
    new_state = Map.delete(state, 'tcp_pid')
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:send_data, type, message}, _from, state) do
    pid = Map.get(state, 'tcp_pid')

    send(pid, {:send_data, type, message})
    {:reply, :ok, state}
  end
end
