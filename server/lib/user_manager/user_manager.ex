defmodule UserManager do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:req_login, user_uuid, user_id, password_with_nonce}, _from, state) do
    user = Map.get(state, user_id)

    result = verify_user_pass(user.password, user.nonce, password_with_nonce)

    if result do
      token = Bcrypt.Base.gen_salt(12, false)
      user = Map.put(user, :token, token)
      user = Map.put(user, :uuid, user_uuid)
      user = Map.put(user, :nonce, nil)
      new_state = Map.put(state, user_id, user)

      {:reply, token, new_state}
    else
      nil_token = <<0::size(29 * 8)>>

      user = Map.put(user, :nonce, nil)
      new_state = Map.put(state, user_id, user)

      {:reply, nil_token, new_state}
    end
  end

  @impl true
  def handle_call({:req_signup, user_uuid, user_id, hashed_password}, _from, state) do
    if !exists_user_id(state, user_id) do
      user = %{
        id: user_id,
        uuid: user_uuid,
        password: hashed_password,
        nonce: nil,
        token: Bcrypt.Base.gen_salt(12, false)
      }

      new_state = Map.put(state, user_id, user)

      {:reply, user.token, new_state}
    else
      nil_token = <<0::size(29 * 8)>>

      {:reply, nil_token, state}
    end
  end

  @impl true
  def handle_call({:req_nonce, user_id}, _from, state) do
    user = Map.get(state, user_id)

    nonce = Bcrypt.Base.gen_salt(12, false)

    user = Map.put(user, :nonce, nonce)
    new_state = Map.put(state, user_id, user)

    {:reply, nonce, new_state}
  end

  @impl true
  def handle_call({:verify_token, user_uuid, user_id, token}, _from, state) do
    user = Map.get(state, user_id)

    result = user.token == token && user.uuid == user_uuid

    {:reply, result, state}
  end

  defp exists_user_id(state, user_id) do
    Enum.any?(Map.values(state), fn user -> user.id == user_id end)
  end

  defp verify_user_pass(password, nonce, pass_with_nonce)
       when is_nil(password) or is_nil(nonce) or is_nil(pass_with_nonce) do
    false
  end

  defp verify_user_pass(password, nonce, pass_with_nonce) do
    pass_with_nonce_stored = Bcrypt.Base.hash_password(password, nonce)

    pass_with_nonce == pass_with_nonce_stored
  end
end
