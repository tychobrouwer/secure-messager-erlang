defmodule DbManager.Message do
  use Ecto.Schema

  require Logger

  alias DbManager.Repo, as: Repo
  alias DbManager.User, as: User
  alias DbManager.Message, as: Message

  alias Ecto.Changeset, as: Changeset

  @primary_key {:message_id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema("messages") do
    field(:tag, :binary)
    field(:hash, :binary)
    field(:public_key, :binary)
    field(:message, :binary)

    timestamps()

    belongs_to(:sender, User, foreign_key: :sender_id, references: :user_id)
    belongs_to(:reciever, User, foreign_key: :receiver_id, references: :user_id)
  end

  def changeset(message, params \\ %{}) do
    message
    |> Changeset.cast(
      params,
      [:tag, :hash, :public_key, :message, :sender_id, :receiver_id]
    )
    |> Changeset.validate_required([
      :tag,
      :hash,
      :public_key,
      :message,
      :sender_id,
      :receiver_id
    ])
  end

  def receive(sender_id_hash, receiver_id_hash, tag, hash, public_key, message) do
    {:ok, sender_id} = Ecto.UUID.cast(sender_id_hash)
    {:ok, receiver_id} = Ecto.UUID.cast(receiver_id_hash)

    case transaction_wrapper(fn ->
           changset =
             %Message{}
             |> Message.changeset(%{
               tag: tag,
               hash: hash,
               public_key: public_key,
               message: message,
               sender_id: sender_id,
               receiver_id: receiver_id
             })

           Repo.insert(changset)
         end) do
      {:ok, message} ->
        message.message_id

      {:error, changeset} ->
        Repo.rollback(changeset)

        {:error, :failed_to_add_message}
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
