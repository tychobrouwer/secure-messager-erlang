defmodule DbManager.Repo do
  use Ecto.Repo,
    otp_app: :messenger_server,
    adapter: Ecto.Adapters.Postgres

  alias DbManager.Repo, as: Repo
  alias DbManager.User, as: User
  alias DbManager.Message, as: Message

  def addUser(uuid, name, public_key, password, nonce, token) do
    case %User{}
      |> User.changeset(%{
        uuid: uuid,
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

  def addMessage(uuid, sender_uuid, recipient_uuid, tag, hash, public_key, message) do
    Repo.transaction(fn ->
      with {:ok, sender} <- Repo.get_by(User, sender_uuid),
        {:ok, receiver} <- Repo.get_by(User, recipient_uuid),
        {:ok, message} <- 
          %Message{}
          |> Message.changeset(%{
            uuid: uuid,
            tag: tag,
            hash: hash,
            public_key: public_key,
            message: message,
            sender_id: sender.id,
            receiver_id: receiver.id,
          })
          |> Repo.insert()
      do
        message.id
      else 
        {:error, changeset} -> 
          Repo.rollback(changeset)
          {:error, :failed_to_add_message}
      end
    end)
  end
end

