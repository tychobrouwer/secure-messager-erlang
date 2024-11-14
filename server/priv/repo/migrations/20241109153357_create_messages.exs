defmodule DbManager.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change() do
    create(table(:messages)) do
      add(:message_id, :binary_id, primary_key: true)
      add(:tag, :binary, null: false)
      add(:hash, :binary, null: false)
      add(:public_key, :binary, null: false)
      add(:message, :binary, null: false)

      timestamps()
    end
  end
end
