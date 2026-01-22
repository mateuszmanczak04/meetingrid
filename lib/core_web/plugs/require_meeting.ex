defmodule CoreWeb.Plugs.RequireMeeting do
  @moduledoc """
  If meeting of the specified `id` doesn't exist, it redirects
  user back to the home screen (`/meetings` page).
  """

  @behaviour Plug

  alias Core.Meetings
  alias Core.Meetings.Meeting
  use CoreWeb, :verified_routes

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{} = conn, _opts) do
    case Meetings.get_meeting(conn.path_params["id"]) do
      nil -> Phoenix.Controller.redirect(conn, to: ~p"/meetings")
      %Meeting{} = _meeting -> conn
    end
  end
end
