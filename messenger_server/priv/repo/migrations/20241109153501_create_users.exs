defmodule DbManager.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change() do
    create(table(:users)) do
      add(:uuid, :binary)
      add(:name, :binary)
      add(:public_key, :binary)
      add(:password, :binary)
      add(:nonce, :binary)
      add(:token, :binary)
    end
  end
end
