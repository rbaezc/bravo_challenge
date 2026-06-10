defmodule Bravo.Repo do
  use Ecto.Repo,
    otp_app: :bravo,
    adapter: Ecto.Adapters.Postgres
end
