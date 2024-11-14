defmodule DbManager.User do
  use Ecto.Schema

  require Logger

  alias DbManager.Repo, as: Repo
  alias DbManager.User, as: User
  alias DbManager.Message, as: Message

  alias Ecto.Changeset, as: Changeset

  schema("users") do
    field(:id_hash, :binary)
    field(:public_key, :binary)
    field(:password_hash, :binary)
    field(:nonce, :binary)
    field(:token, :binary)

    has_many(:send_messages, Message, foreign_key: :sender_id, references: :id_hash)
    has_many(:received_messages, Message, foreign_key: :receiver_id, references: :id_hash)
  end

  def changeset(user, params \\ %{}) do
    user
    |> Changeset.cast(
      params,
      [:id_hash, :public_key, :password_hash, :nonce, :token]
    )
    |> Changeset.validate_required([:id_hash, :public_key, :password_hash, :token])
    |> Changeset.unique_constraint(:id_hash)
  end

  def signup(id_hash, public_key, password) do
    token = Bcrypt.Base.gen_salt(12, false)
    nonce = nil
    password_hash = Bcrypt.hash_pwd_salt(password)

    case transaction_wrapper(fn ->
           %User{}
           |> User.changeset(%{
             id_hash: id_hash,
             public_key: public_key,
             password_hash: password_hash,
             nonce: nonce,
             token: token
           })
           |> Repo.insert()
         end) do
      {:ok, _} ->
        {:ok, token}

      error ->
        if List.keyfind(error.errors, :id_hash, 0) != nil do
          {:error, :id_hash_exists}
        else
          {:error, :internal_error}
        end
    end
  end

  def login(id_hash, password_with_nonce) do
    case User |> Repo.get_by(id_hash: id_hash) do
      nil ->
        {:error, :login_failed}

      user ->
        result = verify_user_pass(user.password_hash, user.nonce, password_with_nonce)

        if result do
          token = Bcrypt.Base.gen_salt(12, false)

          case transaction_wrapper(fn ->
                 User.changeset(user, %{token: token, nonce: nil})
                 |> Repo.update()
               end) do
            {:ok, _} -> {:ok, token}
            {:error, _} -> {:error, :internal_error}
          end
        else
          case transaction_wrapper(fn ->
                 User.changeset(user, %{nonce: nil})
                 |> Repo.update()
               end) do
            {:ok, _} -> {:error, :login_failed}
            {:error, _} -> {:error, :internal_error}
          end
        end
    end
  end

  def get_user_pub_key(id_hash) do
    case User |> Repo.get_by(id_hash: id_hash) do
      nil ->
        {:error, :user_not_found}

      user ->
        {:ok, user.public_key}
    end
  end

  def gen_nonce(id_hash) do
    nonce = Bcrypt.Base.gen_salt(12, false)

    case User |> Repo.get_by(id_hash: id_hash) do
      nil ->
        {:error, :user_not_found}

      user ->
        case transaction_wrapper(fn ->
               User.changeset(user, %{nonce: nonce})
               |> Repo.update()
             end) do
          {:ok, _} -> nonce
          {:error, _} -> {:error, :internal_error}
        end
    end
  end

  def verify_token(id_hash, token) do
    case User |> Repo.get_by(id_hash: id_hash) do
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

  defp verify_user_pass(password, nonce, pass_with_nonce)
       when is_nil(password) or is_nil(nonce) or is_nil(pass_with_nonce) do
    false
  end

  defp verify_user_pass(password_hash, nonce, pass_with_nonce) do
    pass = :crypto.crypto_one_time(:sha256, nonce, pass_with_nonce, false)

    case Bcrypt.verify_pass(pass, password_hash) do
      true -> true
      _ -> false
    end
  end
end
