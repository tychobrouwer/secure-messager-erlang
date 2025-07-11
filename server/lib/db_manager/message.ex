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
    field(:message_data, :binary)
    field(:inserted_at, :integer)

    belongs_to(:sender, User, foreign_key: :sender_id, references: :user_id)
    belongs_to(:reciever, User, foreign_key: :receiver_id, references: :user_id)
  end

  def changeset(message, params \\ %{}) do
    message
    |> Changeset.cast(
      params,
      [:message_data, :sender_id, :receiver_id]
    )
    |> Changeset.validate_required([
      :message_data,
      :sender_id,
      :receiver_id,
    ])
    |> Changeset.put_change(:inserted_at, :os.system_time(:microsecond))
  end

  def receive(message_data, sender_id_hash, receiver_id_hash) do
    {:ok, sender_id} = Ecto.UUID.cast(sender_id_hash)
    {:ok, receiver_id} = Ecto.UUID.cast(receiver_id_hash)

    case transaction_wrapper(fn ->
           changset =
             %Message{}
             |> Message.changeset(%{
               message_data: message_data,
               sender_id: sender_id,
               receiver_id: receiver_id,
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

  def get_messages(receiver_id_hash, nil, last_us_timestamp) do
    {:ok, receiver_id} = Ecto.UUID.cast(receiver_id_hash)

    Repo.all(
      Query.from(m in Message,
        where:
          m.receiver_id == ^receiver_id and
            m.inserted_at > ^last_us_timestamp
      )
    )
    |> Enum.map(&map_message_data/1)
  end

  def get_messages(receiver_id_hash, sender_id_hash, last_us_timestamp) do
    {:ok, receiver_id} = Ecto.UUID.cast(receiver_id_hash)
    {:ok, sender_id} = Ecto.UUID.cast(sender_id_hash)

    Repo.all(
      Query.from(m in Message,
        where:
          ((m.receiver_id == ^receiver_id and m.sender_id == ^sender_id) or
          (m.sender_id == ^receiver_id and m.receiver_id == ^sender_id)) and
            m.inserted_at > ^last_us_timestamp
      )
    )
    |> Enum.map(&map_message_data/1)
  end

  def map_message_data(db_message) do
    sender_id_hash =
      case Ecto.UUID.dump(db_message.sender_id) do
        {:ok, sender_id_hash} -> sender_id_hash
        _ -> nil
      end

    receiver_id_hash =
      case Ecto.UUID.dump(db_message.receiver_id) do
        {:ok, receiver_id_hash} -> receiver_id_hash
        _ -> nil
      end

    %{
      message_data: db_message.message_data,
      sender_id_hash: sender_id_hash,
      receiver_id_hash: receiver_id_hash,
      insert_at: db_message.inserted_at,
    }
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
