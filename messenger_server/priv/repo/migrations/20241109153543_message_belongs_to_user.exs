defmodule DbManager.Repo.Migrations.MessageBelongsToUser do
  use Ecto.Migration

  def change do
    alter(table(:messages)) do
      add(:sender_id, references(:users))
      add(:receiver_id, references(:users))
    end
  end
end
