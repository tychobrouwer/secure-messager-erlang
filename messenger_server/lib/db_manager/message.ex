defmodule DbManager.Message do
  use Ecto.Schema

  schema("messages") do
    field(:tag, :binary)
    field(:hash, :binary)
    field(:public_key, :binary)
    field(:message, :binary)

    belongs_to(:sender, DbManager.User, [foreign_key: :sender_id])
    belongs_to(:reciever, DbManager.User, [foreign_key: :receiver_id])
  end

  def changeset(message, params \\ %{}) do
    message
    |> Ecto.Changeset.cast(params,
      [:tag, :hash, :public_key, :message, :sender_id, :receiver_id]
    )
    |> Ecto.Changeset.validate_required(
      [:tag, :hash, :public_key, :message, :sender_id, :receiver_id]
    )
  end
end

