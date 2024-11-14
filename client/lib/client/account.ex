defmodule Client.Account do
  @moduledoc """

  """

  require Logger

  def login(user_id, user_password) do
    user_id_hash = :crypto.hash(:sha, user_id)

    message_id = GenServer.call(TCPServer, {:get_message_id})

    nonce =
      case TCPServer.send_receive_data(:req_nonce, message_id, user_id_hash) do
        {:error, reason} ->
          Logger.error("Failed to get nonce for user id: #{user_id}, reason: #{reason}")
          exit("Failed to get nonce")

        nonce ->
          nonce
      end

    # Should be retrieved from the local database
    local_salt = "$2b$12$B13AAtXc39YohiOdbtiU6O"

    password_hash = Bcrypt.Base.hash_password(user_password, local_salt)
    password_hash_with_nonce = :crypto.crypto_one_time(:sha256, nonce, password_hash, true)

    login_data = user_id_hash <> password_hash_with_nonce

    message_id = GenServer.call(TCPServer, {:get_message_id})

    case TCPServer.send_receive_data(:req_login, message_id, login_data) do
      {:error, reason} ->
        Logger.error("Login failed with user id: #{user_id}, reason: #{reason}")

      token ->
        GenServer.cast(TCPServer, {:set_auth_token, token})
        GenServer.cast(TCPServer, {:set_auth_id, user_id_hash})

        Logger.notice("Login successful with user id: #{user_id}")

        token
    end
  end

  def signup(user_id, user_password) do
    # Should be generated here and stored in the local database
    # local_salt = Bcrypt.Base.gen_salt(12, false)
    local_salt = "$2b$12$B13AAtXc39YohiOdbtiU6O"

    public_key = GenServer.call(ContactManager, {:generate_keypair})
    password_hash = Bcrypt.Base.hash_password(user_password, local_salt)

    user_id_hash = :crypto.hash(:sha, user_id)
    signup_data = user_id_hash <> public_key <> password_hash

    message_id = GenServer.call(TCPServer, {:get_message_id})

    case TCPServer.send_receive_data(:req_signup, message_id, signup_data) do
      {:error, reason} ->
        Logger.error("Signup failed with user id: #{user_id}, reason: #{reason}")

      token ->
        GenServer.cast(TCPServer, {:set_auth_token, token})
        GenServer.cast(TCPServer, {:set_auth_id, user_id_hash})

        Logger.notice("Signup successful with user id: #{user_id}")

        token
    end
  end
end
