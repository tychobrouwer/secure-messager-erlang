defmodule DbManager.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change() do
    create(table(:people)) do
      add(:uuid, :binary)
      add(:id, :binary)
      add(:public_key, :binary)
      add(:password, :binary)
      add(:none, :binary)
      add(:token, :binary)
    end
  end
end


