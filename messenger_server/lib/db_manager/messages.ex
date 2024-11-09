defmodule DbManager.Message do
  use Ecto.Schema

  schema("messages") do
    field(:uuid, :binary)
    field(:sender_uuid, :binary)
    field(:recipient_uuid, :binary)
    field(:tag, :binary)
    field(:hash, :binary)
    field(:public_key, :binary)
    field(:message, :binary)
  end
end

