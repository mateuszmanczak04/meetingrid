defmodule CoreWeb.Meetings.IndexLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  import CoreWeb.CoreComponents

  @impl true
  def mount(_params, %{"browser_id" => browser_id}, socket) do
    {:ok, assign(socket, :browser_id, browser_id)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    attendees = Meetings.list_attendees_by(browser_id: socket.assigns.browser_id)
    meetings = Enum.map(attendees, &Meetings.get_meeting(&1.meeting_id))
    {:noreply, assign(socket, :meetings, meetings)}
  end

  @impl true
  def handle_event("create_meeting", _params, socket) do
    meeting = Meetings.create_meeting!(%{title: "Untitled"})
    {:noreply, push_navigate(socket, to: ~p"/meetings/#{meeting.id}", replace: true)}
  end
end
