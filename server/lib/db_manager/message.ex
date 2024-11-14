defmodule DbManager.Message do
  use Ecto.Schema

  alias DbManager.Repo, as: Repo
  alias DbManager.User, as: User
  alias DbManager.Message, as: Message

  alias Ecto.Changeset, as: Changeset

  @primary_key {:uuid, :binary_id, autogenerate: true}

  schema("messages") do
    field(:tag, :binary)
    field(:hash, :binary)
    field(:public_key, :binary)
    field(:message, :binary)

    belongs_to(:sender, User, foreign_key: :sender_id, references: :id_hash)
    belongs_to(:reciever, User, foreign_key: :receiver_id, references: :id_hash)
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

  def receive(sender_id, receiver_id, tag, hash, public_key, message) do
    case transaction_wrapper(fn ->
           %Message{}
           |> Message.changeset(%{
             tag: tag,
             hash: hash,
             public_key: public_key,
             message: message,
             sender_id: sender_id,
             receiver_id: receiver_id
           })
           |> Repo.insert()
         end) do
      {:ok, message} ->
        message.uuid

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
