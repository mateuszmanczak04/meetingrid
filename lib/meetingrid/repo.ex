defmodule Meetingrid.Repo do
  use Ecto.Repo,
    otp_app: :meetingrid,
    adapter: Ecto.Adapters.Postgres
end
