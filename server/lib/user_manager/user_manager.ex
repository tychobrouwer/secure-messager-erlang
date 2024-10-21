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
    user = Map.get(state, user_uuid)

    if verify_user(user, user_id) do
      result = verify_user_pass(user.password, user.nonce, password_with_nonce)

      {:reply, result, state}
    else
      {:reply, false, state}
    end
  end

  @impl true
  def handle_call({:req_signup, user_uuid, user_id, hashed_password}, _from, state) do
    if !exists_user_id(state, user_id) do
      user = %{
        id: user_id,
        password: hashed_password,
        nonce: nil,
        token: nil
      }

      new_state = Map.put(state, user_uuid, user)

      {:reply, true, new_state}
    else
      {:reply, false, state}
    end
  end

  @impl true
  def handle_call({:req_nonce, user_uuid, user_id}, _from, state) do
    user = Map.get(state, user_uuid)

    if verify_user(user, user_id) do
      nonce = Bcrypt.Base.gen_salt(12, false)

      user = Map.put(user, :nonce, nonce)
      new_state = Map.put(state, user_uuid, user)

      {:reply, nonce, new_state}
    else
      {:reply, nil, state}
    end
  end

  defp exists_user_id(state, user_id) do
    Enum.any?(Map.values(state), fn user -> user.id == user_id end)
  end

  defp verify_user(user, user_id) when is_nil(user) or is_nil(user_id) do
    false
  end

  defp verify_user(user, user_id) do
    if user.id != user_id do
      false
    else
      true
    end
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
