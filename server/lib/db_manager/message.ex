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
    # field(:tag, :binary)
    # field(:hash, :binary)
    # field(:public_key, :binary)
    # field(:message, :binary)

    field(:message_data, :binary)
    field(:inserted_at, :integer)
    # field(:send_at, :integer)
    # field(:received_at, :integer)

    belongs_to(:sender, User, foreign_key: :sender_id, references: :user_id)
    belongs_to(:reciever, User, foreign_key: :receiver_id, references: :user_id)
  end

  def changeset(message, params \\ %{}) do
    message
    |> Changeset.cast(
      params,
      [:message_data, :sender_id, :receiver_id]
      # [:tag, :hash, :public_key, :message, :sender_id, :receiver_id, :send_at]
    )
    |> Changeset.validate_required([
      :message_data,
      # :tag,
      # :hash,
      # :public_key,
      # :message,
      :sender_id,
      :receiver_id,
      # :send_at
    ])
    |> Changeset.put_change(:inserted_at, :os.system_time(:microsecond))
  end

  def receive(message_data, sender_id_hash, receiver_id_hash) do
    # %{
    #   sender_id_hash: sender_id_hash,
    #   receiver_id_hash: receiver_id_hash
    # } = message_data

    {:ok, sender_id} = Ecto.UUID.cast(sender_id_hash)
    {:ok, receiver_id} = Ecto.UUID.cast(receiver_id_hash)

    case transaction_wrapper(fn ->
           changset =
             %Message{}
             |> Message.changeset(%{
              #  tag: message_data.tag,
              #  hash: message_data.hash,
              #  public_key: message_data.public_key,
              #  message: message_data.message,
               message_data: message_data,
               sender_id: sender_id,
               receiver_id: receiver_id,
              #  send_at: message_data.send_at
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
    # |> Enum.map(&set_message_received_at/1)
    |> Enum.map(&map_message_data/1)
  end

  def get_messages(receiver_id_hash, sender_id_hash, last_us_timestamp) do
    {:ok, receiver_id} = Ecto.UUID.cast(receiver_id_hash)
    {:ok, sender_id} = Ecto.UUID.cast(sender_id_hash)

    Repo.all(
      Query.from(m in Message,
        where:
          m.receiver_id == ^receiver_id and m.sender_id == ^sender_id and
            m.inserted_at > ^last_us_timestamp
      )
    )
    # |> Enum.map(&set_message_received_at/1)
    |> Enum.map(&map_message_data/1)
  end

  # def set_message_received_at(db_message) do
  #   if db_message.received_at == nil do
  #     db_message.received_at = :os.system_time(:microsecond)

  #     case Repo.update(db_message) do
  #       {:ok, _} -> db_message
  #       _ -> :error
  #     end
  #   else
  #     db_message
  #   end
  # end

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

    # Logger.notice(inspect(db_message.sender_id))
    # Logger.notice(inspect(sender_id_hash))

    %{
      # tag: db_message.tag,
      # hash: db_message.hash,
      # public_key: db_message.public_key,
      # message: db_message.message,
      message_data: db_message.message_data,
      sender_id_hash: sender_id_hash,
      receiver_id_hash: receiver_id_hash,
      insert_at: db_message.inserted_at,
      # send_at: db_message.send_at,
      # received_at: db_message.received_at
    }
  end

  # def convert_uuids(message) do
  #   sender_id_hash =
  #     case Ecto.UUID.dump(message.sender_id) do
  #       {:ok, sender_id_hash} -> String.replace(sender_id_hash, "-", "")
  #       _ -> nil
  #     end

  #   receiver_id_hash =
  #     case Ecto.UUID.dump(message.receiver_id) do
  #       {:ok, receiver_id_hash} -> String.replace(receiver_id_hash, "-", "")
  #       _ -> nil
  #     end

  #   Map.put(message, :sender_id_hash, sender_id_hash)
  #   Map.put(message, :receiver_id_hash, receiver_id_hash)
  #   Map.delete(message, :sender_id)
  #   Map.delete(message, :receiver_id)

  #   message
  # end

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
