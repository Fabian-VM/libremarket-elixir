defmodule Repositorio do
  use Ecto.Repo,
    otp_app: :repo,
    adapter: Ecto.Adapters.Postgres
end
