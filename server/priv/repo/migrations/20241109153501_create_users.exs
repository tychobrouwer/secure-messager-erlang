defmodule DbManager.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change() do
    create(table(:users)) do
      add(:user_id, :binary_id, primary_key: true)
      add(:public_key, :binary, null: false)
      add(:password_hash, :binary, null: false)
      add(:nonce, :binary)
      add(:token, :binary)

      timestamps()
    end

    create(unique_index(:users, [:user_id]))
  end
end
