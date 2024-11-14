defmodule DbManager.Repo.Migrations.MessageBelongsToUser do
  use Ecto.Migration

  def change do
    alter(table(:messages)) do
      add(:sender_id, references(:users, column: :user_id, type: :binary_id), null: false)
      add(:receiver_id, references(:users, column: :user_id, type: :binary_id), null: false)
    end

    create(index(:messages, [:sender_id]))
    create(index(:messages, [:receiver_id]))
  end
end
