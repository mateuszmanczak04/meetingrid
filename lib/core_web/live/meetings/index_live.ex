defmodule CoreWeb.Meetings.IndexLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  import CoreWeb.CoreComponents
  alias Core.Repo

  @impl true
  def mount(_params, %{"user" => user}, socket) do
    user = user |> Repo.reload() |> Repo.preload(attendees: :meeting)
    {:ok, socket |> assign(:user, user) |> assign(:attendees, user.attendees)}
  end

  @impl true
  def handle_event("create_meeting", _params, socket) do
    {:ok, attendee} =
      Core.Repo.transact(fn ->
        meeting = Meetings.create_meeting!(%{title: "Untitled"})
        attendee = Meetings.create_attendee!(meeting, socket.assigns.user, %{role: :admin})
        {:ok, Repo.preload(attendee, :meeting)}
      end)

    {:noreply, push_navigate(socket, to: ~p"/meetings/#{attendee.meeting.id}", replace: true)}
  end
end
