defmodule CoreWeb.Meetings.IndexLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  import CoreWeb.CoreComponents

  @impl true
  def mount(_params, _session, socket) do
    attendees =
      Meetings.list_user_attendees(
        socket.assigns.current_user,
        preload: [:meeting]
      )

    {:ok, assign(socket, :attendees, attendees)}
  end

  @impl true
  def handle_event("create_meeting", _params, socket) do
    case Meetings.create_meeting(socket.assigns.current_user, %{title: "Untitled"}) do
      {:ok, attendee} ->
        {:noreply, push_navigate(socket, to: ~p"/meetings/#{attendee.meeting.id}", replace: true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Something went wrong")}
    end
  end
end
