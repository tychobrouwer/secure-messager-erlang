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
  def handle_cast({:add_connection, conn_uuid, pid}, state) do
    new_state = Map.put(state, conn_uuid, %{pid: pid, client_id: nil})
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_connection, conn_uuid}, state) do
    new_state = Map.delete(state, conn_uuid)
    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast({:update_connection, binary, binary, binary}, map) ::
          {:noreply, map} | {:noreply, {:error, :not_found}, map}
  def handle_cast({:update_connection, conn_uuid, client_id, client_pub_key}, state) do
    if Map.has_key?(state, conn_uuid) do
      new_state =
        Map.update!(state, conn_uuid, fn conn ->
          Map.put(conn, :client_id, client_id)
        end)

      new_state =
        Map.update!(new_state, conn_uuid, fn conn ->
          Map.put(conn, :client_pub_key, client_pub_key)
        end)

      {:noreply, new_state}
    else
      {:noreply, {:error, :not_found}, state}
    end
  end

  @impl true
  @spec handle_cast({:update_client_pub_key, binary, binary}, map) ::
          {:noreply, map} | {:noreply, {:error, :not_found}, map}
  def handle_cast({:update_client_pub_key, conn_uuid, client_pub_key}, state) do
    if Map.has_key?(state, conn_uuid) do
      new_state =
        Map.update!(state, conn_uuid, fn conn ->
          Map.put(conn, :client_pub_key, client_pub_key)
        end)

      {:noreply, new_state}
    else
      {:noreply, {:error, :not_found}, state}
    end
  end

  @impl true
  @spec handle_call({:send_data, binary, binary, binary}, any, map) ::
          {:reply, :ok, map} | {:reply, {:error, :not_found}, map}
  def handle_call({:send_data, type, conn_uuid, message}, _from, state) do
    case Map.get(state, conn_uuid) do
      %{pid: pid} ->
        send(pid, {:send_data, type, message})
        {:reply, :ok, state}

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  @spec handle_call({:get_client_uuid, binary}, any, map) :: {:reply, binary, map}
  def handle_call({:get_client_uuid, client_id}, _from, state) do
    conn = Enum.find(state, fn {_key, conn} -> conn.client_id == client_id end)

    case conn do
      {conn_uuid, _} ->
        {:reply, conn_uuid, state}

      nil ->
        {:reply, nil, state}
    end
  end

  @impl true
  @spec handle_call({:get_client_id, binary}, any, map) :: {:reply, binary, map}
  def handle_call({:get_client_id, conn_uuid}, _from, state) do
    case Map.get(state, conn_uuid) do
      %{client_id: client_id} ->
        {:reply, client_id, state}

      nil ->
        {:reply, nil, state}
    end
  end

  @impl true
  @spec handle_call({:get_client_pub_key, binary}, any, map) :: {:reply, binary, map}
  def handle_call({:get_client_pub_key, conn_uuid}, _from, state) do
    case Map.get(state, conn_uuid) do
      %{client_pub_key: client_pub_key} ->
        {:reply, client_pub_key, state}

      nil ->
        {:reply, nil, state}
    end
  end

  @impl true
  @spec handle_call({:get_pid, binary}, any, map) :: {:reply, pid, map}
  def handle_call({:get_pid}, _from, state) do
    {:reply, self(), state}
  end
end
