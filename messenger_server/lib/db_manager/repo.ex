defmodule DbManager.Repo do
  use Ecto.Repo,
    otp_app: :messenger_server,
    adapter: Ecto.Adapters.Postgres
end

