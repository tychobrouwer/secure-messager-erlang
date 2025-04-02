defmodule DbManager.Repo.Migrations.Keys do
  use Ecto.Migration

  def change do
    create(table(:keys)) do
      add(:user_id, :binary_id, primary_key: true)
      add(:key, :binary, null: false)

      add(:inserted_at, :bigint, null: false)
    end

    create(unique_index(:keys, [:user_id]))
  end
end
