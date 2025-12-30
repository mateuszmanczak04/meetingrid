defmodule CoreWeb.Plugs.RequireAttendee do
  @behaviour Plug

  import Plug.Conn
  alias Core.Meetings

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{} = conn, _opts) do
    attendee =
      conn
      |> get_session(:attendee)
      |> case do
        nil -> Meetings.create_attendee!(%{name: "Unknown"})
        existing -> Core.Repo.reload(existing)
      end

    put_session(conn, :attendee, attendee)
  end
end
