defmodule DbManager.Repo do
  use Ecto.Repo,
    otp_app: :messenger_server,
    adapter: Ecto.Adapters.Postgres

  alias DbManager.Repo, as: Repo
  alias DbManager.User, as: User
  alias DbManager.Message, as: Message

  def addUser(name, public_key, password, nonce, token) do
    case %User{}
      |> User.changeset(%{
        name: name,
        public_key: public_key,
        password: password,
        nonce: nonce,
        token: token,
      })
      |> Repo.insert()
    do
      {:ok, user} -> user.id

      _ -> {:error, :failed_to_add_user}
    end
  end

  def addMessage(sender_id, receiver_id, tag, hash, public_key, message) do
    case %Message{}
      |> Message.changeset(%{
        tag: tag,
        hash: hash,
        public_key: public_key,
        message: message,
        sender_id: sender_id,
        receiver_id: receiver_id,
      })
      |> Repo.insert()
    do
      {:ok, message} -> message.id 

      {:error, changeset} -> 
        Repo.rollback(changeset)
        {:error, :failed_to_add_message}
    end
  end
end

