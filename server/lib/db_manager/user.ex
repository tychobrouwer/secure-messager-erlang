defmodule DbManager.User do
  use Ecto.Schema

  require Logger

  alias DbManager.Repo, as: Repo
  alias DbManager.User, as: User
  alias DbManager.Message, as: Message
  alias DbManager.Key, as: Key

  alias Ecto.Changeset, as: Changeset

  @foreign_key_type :binary_id

  schema("users") do
    field(:user_id, :binary_id)
    field(:public_key, :binary)
    field(:password_hash, :binary)
    field(:token, :binary)

    field(:inserted_at, :integer)

    has_many(:send_messages, Message, foreign_key: :sender_id, references: :user_id)
    has_many(:received_messages, Message, foreign_key: :receiver_id, references: :user_id)
  end

  def changeset(user, params \\ %{}) do
    user
    |> Changeset.cast(
      params,
      [:user_id, :public_key, :password_hash, :token]
    )
    |> Changeset.validate_required([:user_id, :public_key, :password_hash])
    |> Changeset.unique_constraint(:user_id)
    |> Changeset.put_change(:inserted_at, :os.system_time(:microsecond))
  end

  def signup(id_hash, public_key, nonce, encrypted_pass_with_tag) do
    {:ok, user_id} = Ecto.UUID.cast(id_hash)
    case Repo.get_by(Key, user_id: user_id) do
      nil ->
        {:error, :signup_failed}

      key_entry ->
        length = byte_size(encrypted_pass_with_tag)
        <<encrypted_pass::binary-size(length - 16), tag::binary-size(16)>> = encrypted_pass_with_tag

        password = :crypto.crypto_one_time_aead(:aes_256_gcm, key_entry.key, nonce, encrypted_pass, "", tag, false)

        Repo.delete(key_entry)

        token = :crypto.strong_rand_bytes(32)
        password_hash = Bcrypt.hash_pwd_salt(password)

        case transaction_wrapper(fn ->
              %User{}
              |> User.changeset(%{
                user_id: user_id,
                public_key: public_key,
                password_hash: password_hash,
                token: token
              })
              |> Repo.insert()
            end) do
          {:ok, _} ->
            {:ok, token}

          error ->
            if List.keyfind(error.errors, :user_id, 0) != nil do
              {:error, :user_exists}
            else
              {:error, :internal_error}
            end
        end
    end
  end

  def login(id_hash, nonce, encrypted_pass) do
    {:ok, user_id} = Ecto.UUID.cast(id_hash)

    case User |> Repo.get_by(user_id: user_id) do
      nil ->
        {:error, :login_failed}

      user ->
        case Repo.get_by(Key, user_id: user_id) do
          nil ->
            {:error, :login_failed}

          key_entry ->

            verify = verify_user_pass(user.password_hash, key_entry.key, nonce, encrypted_pass)
            token = if verify, do: :crypto.strong_rand_bytes(32), else: nil

            Repo.delete(key_entry)

            update_token(user, token)
        end
    end
  end

  def exists(id_hash) do
    {:ok, user_id} = Ecto.UUID.cast(id_hash)

    case User |> Repo.get_by(user_id: user_id) do
      nil -> false
      _ -> true
    end
  end

  def update_token(user, token) do
    case {
      transaction_wrapper(fn ->
        User.changeset(user, %{token: token})
        |> Repo.update()
      end),
      token
    } do
      {{:ok, _}, nil} -> {:error, :login_failed}
      {{:ok, _}, token} -> {:ok, token}
      {{:error, _}, _} -> {:error, :internal_error}
    end
  end

  def pub_key(id_hash) do
    {:ok, user_id} = Ecto.UUID.cast(id_hash)

    case User |> Repo.get_by(user_id: user_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        {:ok, user.public_key}
    end
  end

  def verify_token(id_hash, token) do
    {:ok, user_id} = Ecto.UUID.cast(id_hash)

    case User |> Repo.get_by(user_id: user_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        if user.token == token do
          {:ok, true}
        else
          {:ok, false}
        end
    end
  end

  defp verify_user_pass(password, key, nonce, encrypted_pass_with_tag)
       when is_nil(password) or is_nil(key) or is_nil(nonce) or is_nil(encrypted_pass_with_tag) do
    false
  end

  defp verify_user_pass(password_hash, key, nonce, encrypted_pass_with_tag) do
    length = byte_size(encrypted_pass_with_tag)
    <<encrypted_pass::binary-size(length - 16), tag::binary-size(16)>> = encrypted_pass_with_tag

    pass = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, encrypted_pass, "", tag, false)

    case Bcrypt.verify_pass(pass, password_hash) do
      true -> true
      _ -> false
    end
  end

  defp transaction_wrapper(fun) do
    case Repo.transaction(fn ->
           with {:ok, result} <- fun.() do
             {:ok, result}
           else
             {:error, changeset} ->
               Repo.rollback(changeset)

               {:error, :failed_transaction}
           end
         end) do
      {_, result} ->
        result
    end
  end
end
