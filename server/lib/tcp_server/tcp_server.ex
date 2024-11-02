defmodule TCPServer do
  use GenServer

  require Logger

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
  def handle_cast({:add_connection, conn_uuid, pid}, state)
      when verify_bin(conn_uuid, 20) and is_pid(pid) do
    new_state = Map.put(state, conn_uuid, %{pid: pid, user_id: nil})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_connection, conn_uuid}, state) when verify_bin(conn_uuid, 20) do
    new_state = Map.delete(state, conn_uuid)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_connection, conn_uuid, user_id, user_pub_key}, state)
      when verify_bin(conn_uuid, 20) and verify_bin(user_id, 16) and
             verify_bin(user_pub_key, 32) do
    if Map.has_key?(state, conn_uuid) do
      new_state = put_in(state, [conn_uuid, :user_id], user_id)
      new_state = put_in(new_state, [conn_uuid, :user_pub_key], user_pub_key)

      {:noreply, new_state}
    else
      {:reply, state}
    end
  end

  @impl true
  def handle_cast({:update_connection, conn_uuid, user_id, _user_pub_key}, state)
      when verify_bin(conn_uuid, 20) and verify_bin(user_id, 16) do
    if Map.has_key?(state, conn_uuid) do
      new_state = put_in(state, [conn_uuid, :user_id], user_id)

      {:noreply, new_state}
    else
      {:reply, state}
    end
  end

  @impl true
  def handle_cast({:update_connection, conn_uuid, _user_id, user_pub_key}, state)
      when verify_bin(conn_uuid, 20) and verify_bin(user_pub_key, 32) do
    if Map.has_key?(state, conn_uuid) do
      new_state = put_in(state, [conn_uuid, :user_pub_key], user_pub_key)

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
  def handle_call({:send_data, type, conn_uuid, message_id, message}, _from, state)
      when verify_bin(conn_uuid, 20) do
    case Map.get(state, conn_uuid) do
      %{pid: pid} ->
        send(pid, {:send_data, type, message_id, message})
        {:reply, :ok, state}

      _ ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_user_uuid, user_id}, _from, state) when verify_bin(user_id, 16) do
    conn = Enum.find(state, fn {_key, conn} -> conn.user_id == user_id end)

    case conn do
      {conn_uuid, _} ->
        {:reply, conn_uuid, state}

      _ ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_user_id, user_uuid}, _from, state) when verify_bin(user_uuid, 20) do
    case Map.get(state, user_uuid) do
      %{user_id: user_id} ->
        {:reply, user_id, state}

      _ ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_user_pub_key, user_uuid}, _from, state)
      when verify_bin(user_uuid, 20) do
    case Map.get(state, user_uuid) do
      %{user_pub_key: user_pub_key} ->
        {:reply, user_pub_key, state}

      _ ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:verify_user_uuid_id, user_uuid, user_id}, _from, state)
      when verify_bin(user_uuid, 20) and verify_bin(user_id, 16) do
    case Map.get(state, user_uuid) do
      %{user_id: user_id_stored} when user_id == user_id_stored ->
        {:reply, true, state}

      _ ->
        {:reply, false, state}
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
