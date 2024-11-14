defmodule DbManager.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change() do
    create(table(:users)) do
      add(:id_hash, :binary)
      add(:public_key, :binary)
      add(:password_hash, :binary)
      add(:nonce, :binary)
      add(:token, :binary)
    end

    create(unique_index(:users, [:id_hash]))
  end
end
