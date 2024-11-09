defmodule DbManager.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change() do
    create(table(:messages)) do
      add(:sender_uuid, :binary)
      add(:recipient_uuid, :binary)
      add(:message_uuid, :binary)
      add(:tag, :binary)
      add(:hash, :binary)
      add(:public_key, :binary)
      add(:message, :binary)
    end
  end
end
