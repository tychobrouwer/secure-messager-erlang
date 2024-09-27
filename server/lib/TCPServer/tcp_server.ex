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
  def handle_cast({:add_connection, conn_id, pid}, state) do
    new_state = Map.put(state, conn_id, %{pid: pid, client_id: nil})
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_connection, conn_id}, state) do
    new_state = Map.delete(state, conn_id)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_client, conn_id, pid, client_id}, state) do
    if Map.has_key?(state, conn_id) do
      new_state =
        Map.update!(state, conn_id, fn conn -> %{conn | pid: pid, client_id: client_id} end)

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call({:send_data, client_id, type, message}, _from, state) do
    conn_id =
      state
      |> Enum.find(fn {_, conn} -> conn.client_id == client_id end)
      |> elem(0)

    case Map.get(state, conn_id) do
      %{pid: pid} ->
        send(pid, {:send_data, type, message})
        {:reply, :ok, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_client_id, conn_id}, _from, state) do
    case Map.get(state, conn_id) do
      %{client_id: client_id} ->
        {:reply, client_id, state}

      nil ->
        {:reply, nil, state}
    end
  end
end
