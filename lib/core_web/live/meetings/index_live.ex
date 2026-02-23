defmodule CoreWeb.Meetings.IndexLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  import CoreWeb.CoreComponents
  alias Core.Auth

  @impl true
  def mount(_params, %{"user_id" => current_user_id}, socket) do
    user = Auth.get_user(current_user_id, preload: [attendees: :meeting])
    {:ok, socket |> assign(:user, user) |> assign(:attendees, user.attendees)}
  end

  @impl true
  def handle_event("create_meeting", _params, socket) do
    case Meetings.create_meeting(socket.assigns.user, %{title: "Untitled"}) do
      {:ok, attendee} ->
        {:noreply, push_navigate(socket, to: ~p"/meetings/#{attendee.meeting.id}", replace: true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Something went wrong")}
    end
  end
end
