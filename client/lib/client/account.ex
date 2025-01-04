defmodule Client.Account do
  @moduledoc """

  """

  require Logger

  def login(user_id, user_password) do
    user_id_hash = :crypto.hash(:md4, user_id)

    # TODO: Should be read from the local database seperate for each account
    GenServer.call(ContactManager, {:generate_keypair})

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

    pass = Bcrypt.Base.hash_password(user_password, local_salt)
    pass = pkcs7_pad(pass, 16)

    pass_with_nonce = :crypto.crypto_one_time(:aes_256_ecb, nonce, pass, true)

    login_data = user_id_hash <> pass_with_nonce

    message_id = GenServer.call(TCPServer, {:get_message_id})

    case TCPServer.send_receive_data(:req_login, message_id, login_data) do
      {:error, reason} ->
        Logger.error("Login failed with user id: #{user_id}, reason: #{reason}")

      token ->
        GenServer.cast(TCPServer, {:set_auth, token, user_id_hash})

        Logger.notice("Login successful with user id: #{user_id}")
        Client.Message.request_new()

        token
    end
  end

  def signup(user_id, user_password) do
    # TODO: Should be generated here and stored in the local database seperate for each account
    # local_salt = Bcrypt.Base.gen_salt(12, false)
    local_salt = "$2b$12$B13AAtXc39YohiOdbtiU6O"

    # TODO: Should be generated here and stored in the local database seperate for each account
    public_key = GenServer.call(ContactManager, {:generate_keypair})

    pass = Bcrypt.Base.hash_password(user_password, local_salt)

    user_id_hash = :crypto.hash(:md4, user_id)
    signup_data = user_id_hash <> public_key <> pass

    message_id = GenServer.call(TCPServer, {:get_message_id})

    case TCPServer.send_receive_data(:req_signup, message_id, signup_data) do
      {:error, reason} ->
        Logger.error("Signup failed with user id: #{user_id}, reason: #{reason}")

      token ->
        GenServer.cast(TCPServer, {:set_auth, token, user_id_hash})

        Logger.notice("Signup successful with user id: #{user_id}")

        token
    end
  end

  def logout() do
    message_id = GenServer.call(TCPServer, {:get_message_id})

    TCPServer.send_receive_data(:req_logout, message_id, <<0>>)
    GenServer.cast(TCPServer, {:logout})

    Logger.notice("Logout successful")
  end

  defp pkcs7_pad(data, block_size) do
    padding = block_size - rem(byte_size(data), block_size)
    padding = if padding == 0, do: block_size, else: padding

    data <> :binary.copy(<<padding::size(8)>>, padding)
  end
end
