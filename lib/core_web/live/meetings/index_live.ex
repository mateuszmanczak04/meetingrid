defmodule CoreWeb.Meetings.IndexLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  import CoreWeb.CoreComponents

  @impl true
  def mount(_params, %{"user" => user}, socket) do
    {:ok, assign(socket, :user, user)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    user = Core.Repo.preload(socket.assigns.user, attendees: :meeting)
    {:noreply, assign(socket, :attendees, user.attendees)}
  end

  @impl true
  def handle_event("create_meeting", _params, socket) do
    {:ok, attendee} =
      Core.Repo.transact(fn ->
        meeting = Meetings.create_meeting!(%{title: "Untitled"})
        attendee = Meetings.create_attendee!(meeting, socket.assigns.user, %{role: :admin})
        {:ok, Core.Repo.preload(attendee, :meeting)}
      end)

    {:noreply, push_navigate(socket, to: ~p"/meetings/#{attendee.meeting.id}", replace: true)}
  end
end
