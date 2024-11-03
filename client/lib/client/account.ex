defmodule Client.Account do
  @moduledoc """

  """

  require Logger

  def login(user_id, user_password) do
    user_id_hash = :crypto.hash(:md4, user_id)

    message_id = GenServer.call(TCPServer, {:get_message_id})
    nonce = TCPServer.get_async_server_value(:req_nonce, message_id, user_id_hash)

    Logger.notice("Attempting login with user id: #{user_id}")

    local_salt = "$2b$12$B13AAtXc39YohiOdbtiU6O"

    hashed_password = Bcrypt.Base.hash_password(user_password, local_salt)
    hashed_password_with_nonce = Bcrypt.Base.hash_password(hashed_password, nonce)

    login_data = user_id_hash <> hashed_password_with_nonce

    message_id = GenServer.call(TCPServer, {:get_message_id})
    token = TCPServer.get_async_server_value(:req_login, message_id, login_data)

    GenServer.cast(TCPServer, {:set_auth_token, token})
    GenServer.cast(TCPServer, {:set_auth_id, user_id_hash})

    Logger.notice("Login successful with user id: #{user_id}")

    token
  end

  def signup(user_id, user_password) do
    # Should be generated here and stored in the local database
    # local_salt = Bcrypt.Base.gen_salt(12, false)
    local_salt = "$2b$12$B13AAtXc39YohiOdbtiU6O"

    hashed_password = Bcrypt.Base.hash_password(user_password, local_salt)

    Logger.notice("Attempting signup with user id: #{user_id}")

    user_id_hash = :crypto.hash(:md4, user_id)
    signup_data = user_id_hash <> hashed_password

    message_id = GenServer.call(TCPServer, {:get_message_id})
    token = TCPServer.get_async_server_value(:req_signup, message_id, signup_data)

    GenServer.cast(TCPServer, {:set_auth_token, token})
    GenServer.cast(TCPServer, {:set_auth_id, user_id_hash})

    Logger.notice("Signup successful with user id: #{user_id}")

    token
  end
end
