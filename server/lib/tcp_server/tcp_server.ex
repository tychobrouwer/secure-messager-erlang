defmodule TCPServer do
  use GenServer

  require Logger

  defmacro verify_bin(binary, length) do
    quote do
      is_binary(unquote(binary)) and byte_size(unquote(binary)) == unquote(length)
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_connection, conn_uuid, pid}, state)
      when verify_bin(conn_uuid, 20) and is_pid(pid) do
    new_state = Map.put(state, conn_uuid, %{pid: pid, client_id: nil})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_connection, conn_uuid}, state) when verify_bin(conn_uuid, 20) do
    new_state = Map.delete(state, conn_uuid)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_connection, conn_uuid, client_id, client_pub_key}, state)
      when verify_bin(conn_uuid, 20) and verify_bin(client_id, 16) and
             verify_bin(client_pub_key, 32) do
    if Map.has_key?(state, conn_uuid) do
      new_state = put_in(state, [conn_uuid, :client_id], client_id)
      new_state = put_in(new_state, [conn_uuid, :client_pub_key], client_pub_key)

      {:noreply, new_state}
    else
      {:reply, state}
    end
  end

  @impl true
  def handle_cast({:update_connection, conn_uuid, client_id, _client_pub_key}, state)
      when verify_bin(conn_uuid, 20) and verify_bin(client_id, 16) do
    if Map.has_key?(state, conn_uuid) do
      new_state = put_in(state, [conn_uuid, :client_id], client_id)

      {:noreply, new_state}
    else
      {:reply, state}
    end
  end

  @impl true
  def handle_cast({:update_connection, conn_uuid, _client_id, client_pub_key}, state)
      when verify_bin(conn_uuid, 20) and verify_bin(client_pub_key, 32) do
    if Map.has_key?(state, conn_uuid) do
      new_state = put_in(state, [conn_uuid, :client_pub_key], client_pub_key)

      {:noreply, new_state}
    else
      {:reply, state}
    end
  end

  @impl true
  def handle_cast(request, state) do
    Logger.error("Unknown cast request -> #{inspect(request)}")

    {:noreply, state}
  end

  @impl true
  def handle_call({:send_data, type, conn_uuid, message}, _from, state)
      when verify_bin(conn_uuid, 20) do
    case Map.get(state, conn_uuid) do
      %{pid: pid} ->
        send(pid, {:send_data, type, message})
        {:reply, :ok, state}

      nil ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_client_uuid, client_id}, _from, state) when verify_bin(client_id, 16) do
    conn = Enum.find(state, fn {_key, conn} -> conn.client_id == client_id end)

    case conn do
      {conn_uuid, _} ->
        {:reply, conn_uuid, state}

      nil ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_client_id, conn_uuid}, _from, state) when verify_bin(conn_uuid, 20) do
    case Map.get(state, conn_uuid) do
      %{client_id: client_id} ->
        {:reply, client_id, state}

      nil ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_client_pub_key, conn_uuid}, _from, state)
      when verify_bin(conn_uuid, 20) do
    case Map.get(state, conn_uuid) do
      %{client_pub_key: client_pub_key} ->
        {:reply, client_pub_key, state}

      nil ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_pid}, _from, state) do
    {:reply, self(), state}
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.error("Unknown call request -> #{inspect(request)}")

    {:reply, nil, state}
  end
end
