defmodule TCPServer do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_connection, conn_uuid, pid}, state) do
    new_state = Map.put(state, conn_uuid, %{pid: pid, user_id_hash: nil})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_connection, conn_uuid}, state) do
    new_state = Map.delete(state, conn_uuid)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_connection, conn_uuid, user_id_hash}, state) do
    if Map.has_key?(state, conn_uuid) do
      new_state = put_in(state, [conn_uuid, :user_id_hash], user_id_hash)

      {:noreply, new_state}
    else
      {:reply, state}
    end
  end

  @impl true
  def handle_cast(request, state) do
    Logger.error("Unknown cast request tcp_server -> #{inspect(request)}")

    {:noreply, state}
  end

  @impl true
  def handle_call({:send_data, type, conn_uuid, message_id, message}, _from, state) do
    case Map.get(state, conn_uuid) do
      %{pid: pid} ->
        send(pid, {:send_data, type, message_id, message})
        {:reply, :ok, state}

      _ ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_connection_id_hash, req_user_id_hash}, _from, state) do
    conn_uuid =
      Enum.find_value(state, fn {conn_uuid, %{user_id_hash: user_id_hash}} ->
        if user_id_hash == req_user_id_hash do
          conn_uuid
        end
      end)

    {:reply, conn_uuid, state}
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.error("Unknown call request tcp_server -> #{inspect(request)}")

    {:reply, nil, state}
  end
end
