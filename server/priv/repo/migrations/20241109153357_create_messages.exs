defmodule DbManager.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change() do
    create(table(:messages)) do
      add(:message_id, :binary_id, primary_key: true)
      # add(:tag, :binary, null: false)
      # add(:hash, :binary, null: false)
      # add(:public_key, :binary, null: false)
      # add(:message, :binary, null: false)
      add(:message_data, :binary, null: false)

      add(:inserted_at, :bigint, null: false)
      # add(:send_at, :bigint, null: false)
      # add(:received_at, :bigint, null: true)
    end
  end
end
