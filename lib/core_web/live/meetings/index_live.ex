defmodule CoreWeb.Meetings.IndexLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  import CoreWeb.CoreComponents

  @impl true
  def mount(_params, %{"attendee" => attendee}, socket) do
    {:ok, assign(socket, :attendee, attendee)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    attendee = Core.Repo.preload(socket.assigns.attendee, meetings: [:attendees])
    {:noreply, assign(socket, :meetings, attendee.meetings)}
  end

  @impl true
  def handle_event("create_meeting", _params, socket) do
    {:ok, meeting_attendee} =
      Core.Repo.transact(fn ->
        meeting = Meetings.create_meeting!(%{title: "Untitled"})

        # TODO: move this part to `Core.Meetings`
        meeting_attendee =
          %Core.Meetings.MeetingsAttendees{role: :admin, available_days: []}
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_assoc(:meeting, meeting)
          |> Ecto.Changeset.put_assoc(:attendee, socket.assigns.attendee)
          |> Core.Repo.insert!()

        {:ok, meeting_attendee}
      end)
      |> dbg()

    {:noreply,
     push_navigate(socket, to: ~p"/meetings/#{meeting_attendee.meeting.id}", replace: true)}
  end
end
