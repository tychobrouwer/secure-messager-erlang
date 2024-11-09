defmodule DbManager.Users do
  use Ecto.Schema

  schema("users") do
    field(:uuid, :binary)
    field(:id, :binary)
    field(:public_key, :binary)
    field(:password, :binary)
    field(:none, :binary)
    field(:token, :binary)
  end
end
