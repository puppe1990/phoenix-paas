defmodule PhoenixPaas.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_paas,
    adapter: Ecto.Adapters.SQLite3
end
