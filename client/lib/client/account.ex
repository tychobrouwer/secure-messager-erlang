defmodule Client.Account do
  @moduledoc """

  """

  require Logger

  def login(user_id, user_password) do
    nonce = TCPServer.async_do(fn -> get_nonce(user_id) end)

    Logger.info("Attempting login with user id: #{user_id}")

    local_salt = "$2b$12$B13AAtXc39YohiOdbtiU6O"

    hashed_password = Bcrypt.Base.hash_password(user_password, local_salt)
    hashed_password_with_nonce = Bcrypt.Base.hash_password(hashed_password, nonce)

    user_id_hash = :crypto.hash(:md4, user_id)
    login_data = user_id_hash <> hashed_password_with_nonce

    TCPServer.async_do(fn -> do_login(login_data) end)
  end

  def signup(user_id, user_password) do
    # Should be generated here and stored in the local database
    # local_salt = Bcrypt.Base.gen_salt(12, false)
    local_salt = "$2b$12$B13AAtXc39YohiOdbtiU6O"

    hashed_password = Bcrypt.Base.hash_password(user_password, local_salt)

    Logger.info("Attempting signup with user id: #{user_id}")

    user_id_hash = :crypto.hash(:md4, user_id)
    signup_data = user_id_hash <> hashed_password

    TCPServer.async_do(fn -> do_signup(signup_data) end)
  end

  @spec get_nonce(binary) :: binary
  defp get_nonce(user_id) do
    user_id_hash = :crypto.hash(:md4, user_id)
    GenServer.cast(TCPServer, {:send_data, :req_nonce, user_id_hash, :no_auth})

    receive do
      {:req_nonce_response, nonce} ->
        nonce
    after
      5000 ->
        Logger.warning("Timeout waiting for signup data")
        exit(:timeout)
    end
  end

  @spec do_login(binary) :: binary
  defp do_login(login_data) do
    GenServer.cast(TCPServer, {:send_data, :req_login, login_data, :no_auth})

    receive do
      {:req_login_response, token} ->
        token
    after
      5000 ->
        Logger.warning("Timeout waiting for signup data")
        exit(:timeout)
    end
  end

  @spec do_signup(binary) :: binary
  defp do_signup(signup_data) do
    GenServer.cast(TCPServer, {:send_data, :req_signup, signup_data, :no_auth})

    receive do
      {:req_signup_response, token} ->
        token
    after
      5000 ->
        Logger.warning("Timeout waiting for signup data")
        exit(:timeout)
    end
  end
end
