defmodule DbManager.User do
  use Ecto.Schema

  schema("users") do
    field(:name, :binary)
    field(:public_key, :binary)
    field(:password, :binary)
    field(:nonce, :binary)
    field(:token, :binary)
    
    has_many(:sender_messages, DbManager.Message, [foreign_key: :sender_id])
    has_many(:receiver_messages, DbManager.Message, [foreign_key: :receiver_id])
  end
  
  def changeset(user, params \\ %{}) do
    user
    |> Ecto.Changeset.cast(params,
      [:name, :public_key, :password, :nonce, :token]
    )
    |> Ecto.Changeset.validate_required(
      [:name, :public_key, :password, :nonce, :token]
    )
  end

end
