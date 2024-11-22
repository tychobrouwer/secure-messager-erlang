defmodule DbManager.Message do
  use Ecto.Schema

  require Logger
  require Ecto.Query

  alias DbManager.Repo, as: Repo
  alias DbManager.User, as: User
  alias DbManager.Message, as: Message

  alias Ecto.Changeset, as: Changeset
  alias Ecto.Query, as: Query

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

  def receive(message_data) do
    %{
      sender_id_hash: sender_id_hash,
      receiver_id_hash: receiver_id_hash
    } = message_data

    {:ok, sender_id} = Ecto.UUID.cast(sender_id_hash)
    {:ok, receiver_id} = Ecto.UUID.cast(receiver_id_hash)

    case transaction_wrapper(fn ->
           changset =
             %Message{}
             |> Message.changeset(%{
               tag: message_data.tag,
               hash: message_data.hash,
               public_key: message_data.public_key,
               message: message_data.message,
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

  def get_messages(receiver_id_hash, sender_id_hash, last_us_timestamp \\ 0)
      when is_nil(sender_id_hash) do
    {:ok, receiver_id} = Ecto.UUID.cast(receiver_id_hash)

    Repo.all(
      Query.from(m in Message,
        where: m.receiver_id == ^receiver_id and m.inserted_at.microsecond > ^last_us_timestamp
      )
    )
  end

  def get_messages(receiver_id_hash, sender_id_hash, last_us_timestamp \\ 0) do
    {:ok, receiver_id} = Ecto.UUID.cast(receiver_id_hash)
    {:ok, sender_id} = Ecto.UUID.cast(sender_id_hash)

    Repo.all(
      Query.from(m in Message,
        where:
          m.receiver_id == ^receiver_id and m.sender_id == ^sender_id and
            m.inserted_at.microsecond > ^last_us_timestamp
      )
    )
  end

  def validate(message_data) do
    Map.has_key?(message_data, :sender_id_hash) and
      Map.has_key?(message_data, :receiver_id_hash) and
      Map.has_key?(message_data, :tag) and
      Map.has_key?(message_data, :hash) and
      Map.has_key?(message_data, :public_key) and
      Map.has_key?(message_data, :message)
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
