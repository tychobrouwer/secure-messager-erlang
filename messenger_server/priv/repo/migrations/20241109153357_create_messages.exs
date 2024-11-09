defmodule DbManager.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change() do
    create(table(:messages)) do
      add(:tag, :binary)
      add(:hash, :binary)
      add(:public_key, :binary)
      add(:message, :binary)
    end
  end
end
