defmodule DbManager.Key do
  use Ecto.Schema

  require Logger

  alias DbManager.Repo, as: Repo
  alias DbManager.Key, as: Key

  alias Ecto.Changeset, as: Changeset

  schema("keys") do
    field(:user_id, :binary_id)
    field(:key, :binary)

    field(:inserted_at, :integer)
  end

  def changeset(key, attrs) do
    key
    |> Changeset.cast(attrs, [:user_id, :key])
    |> Changeset.validate_required([:user_id, :key])
    |> Changeset.unique_constraint(:user_id)
    |> Changeset.put_change(:inserted_at, :os.system_time(:microsecond))
  end

  def key(id_hash) do
    {:ok, user_id} = Ecto.UUID.cast(id_hash)

    key = :crypto.strong_rand_bytes(32)

    case transaction_wrapper(fn ->
            %Key{}
            |> Key.changeset(%{user_id: user_id, key: key})
            |> Repo.insert()
          end) do
      {:ok, _} -> {:ok, key}
      {:error, _} -> {:error, :internal_error}
    end
  end

  defp transaction_wrapper(fun) do
    case Repo.transaction(fn ->
           with {:ok, result} <- fun.() do
             {:ok, result}
           else
             {:error, changeset} ->
               Repo.rollback(changeset)

               {:error, :failed_transaction}
           end
         end) do
      {_, result} ->
        result
    end
  end
end
