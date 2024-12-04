defmodule DbManager.User do
  use Ecto.Schema

  require Logger

  alias DbManager.Repo, as: Repo
  alias DbManager.User, as: User
  alias DbManager.Message, as: Message

  alias Ecto.Changeset, as: Changeset

  @foreign_key_type :binary_id

  schema("users") do
    field(:user_id, :binary_id)
    field(:public_key, :binary)
    field(:password_hash, :binary)
    field(:nonce, :binary)
    field(:token, :binary)

    field(:inserted_at, :integer)

    has_many(:send_messages, Message, foreign_key: :sender_id, references: :user_id)
    has_many(:received_messages, Message, foreign_key: :receiver_id, references: :user_id)
  end

  def changeset(user, params \\ %{}) do
    user
    |> Changeset.cast(
      params,
      [:user_id, :public_key, :password_hash, :nonce, :token]
    )
    |> Changeset.validate_required([:user_id, :public_key, :password_hash])
    |> Changeset.unique_constraint(:user_id)
    |> Changeset.put_change(:inserted_at, :os.system_time(:microsecond))
  end

  def signup(id_hash, public_key, password) do
    {:ok, user_id} = Ecto.UUID.cast(id_hash)

    token = :crypto.strong_rand_bytes(32)
    password_hash = Bcrypt.hash_pwd_salt(password)

    case transaction_wrapper(fn ->
           %User{}
           |> User.changeset(%{
             user_id: user_id,
             public_key: public_key,
             password_hash: password_hash,
             nonce: nil,
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

  def login(id_hash, password_with_nonce) do
    Logger.notice("Login attempt for user: #{id_hash}")

    {:ok, user_id} = Ecto.UUID.cast(id_hash)

    Logger.notice("Login attempt for user: #{user_id}")

    case User |> Repo.get_by(user_id: user_id) do
      nil ->
        {:error, :login_failed}

      user ->
        Logger.notice(inspect(user))

        verify = verify_user_pass(user.password_hash, user.nonce, password_with_nonce)
        token = if verify, do: :crypto.strong_rand_bytes(32), else: nil

        update_token(user, token)
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
        User.changeset(user, %{token: token, nonce: nil})
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

  def nonce(id_hash) do
    {:ok, user_id} = Ecto.UUID.cast(id_hash)

    case User |> Repo.get_by(user_id: user_id) do
      nil ->
        Logger.notice("User not found")

        {:error, :user_not_found}

      user ->
        Logger.notice("#{inspect(user)}")

        nonce = :crypto.strong_rand_bytes(32)

        case transaction_wrapper(fn ->
               User.changeset(user, %{nonce: nonce})
               |> Repo.update()
             end) do
          {:ok, _} -> {:ok, nonce}
          {:error, _} -> {:error, :internal_error}
        end
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

  defp verify_user_pass(password, nonce, pass_with_nonce)
       when is_nil(password) or is_nil(nonce) or is_nil(pass_with_nonce) do
    false
  end

  defp verify_user_pass(password_hash, nonce, pass_with_nonce) do
    pass = :crypto.crypto_one_time(:aes_256_ecb, nonce, pass_with_nonce, false)
    pass = pkcs7_unpad(pass, 16)

    case Bcrypt.verify_pass(pass, password_hash) do
      true -> true
      _ -> false
    end
  end

  defp pkcs7_unpad(data, block_size) do
    length = :binary.last(data)
    length = if length > 0 and length <= block_size, do: length, else: 0

    :binary.part(data, 0, byte_size(data) - length)
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
