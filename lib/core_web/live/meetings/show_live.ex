defmodule CoreWeb.Meetings.ShowLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  alias Core.Meetings.Meeting
  alias Core.Meetings.MeetingServer
  import CoreWeb.Meetings.Guards

  @impl true
  def mount(%{"id" => meeting_id}, %{"user" => user}, socket) do
    # TODO: think about checking if connected?(socket)
    case Meetings.get_meeting(meeting_id) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/meetings")}

      %Meeting{} = _meeting ->
        Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{meeting_id}")

        %{current_attendee: current_attendee, state: state} =
          MeetingServer.join_meeting(meeting_id, user)

        {:ok,
         socket
         |> assign(:current_attendee, current_attendee)
         |> assign(:meeting, state.meeting)
         |> assign(:attendees, state.meeting.attendees)
         |> assign(:common_days, state.common_days)}
    end
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    missing_attendees =
      Enum.filter(socket.assigns.meeting.attendees, fn a ->
        a.id not in Enum.map(state.attendees, & &1.id)
      end)

    if socket.assigns.current_attendee in missing_attendees do
      {:noreply,
       socket
       |> put_flash(:error, "You left or were kicked from the meeting")
       |> push_navigate(to: ~p"/meetings")}
    else
      current_attendee =
        Enum.find(state.attendees, &(&1.id === socket.assigns.current_attendee.id))

      socket =
        Enum.reduce(missing_attendees, socket, fn a, s ->
          put_flash(s, :info, "#{a.user.name} left or was kicked")
        end)

      # current_attendee first, then alphabetically case insensitive
      ordered_attendees =
        Enum.sort(state.attendees, fn a1, a2 ->
          case {a1, a2} do
            {^current_attendee, _} -> true
            {_, ^current_attendee} -> false
            {a1, a2} -> String.downcase(a1.user.name) <= String.downcase(a2.user.name)
          end
        end)

      {:noreply,
       socket
       |> assign(:meeting, state.meeting)
       |> assign(:attendees, ordered_attendees)
       |> assign(:common_days, state.common_days)
       |> assign(:current_attendee, current_attendee)}
    end
  end

  @impl true
  def handle_info(:meeting_deleted, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "This meeting has been deleted")
     |> push_navigate(to: ~p"/meetings")}
  end

  @impl true
  def handle_event("toggle_day", %{"day_number" => day_number}, socket) do
    %{meeting: meeting, current_attendee: current_attendee} = socket.assigns

    available_days =
      if String.to_integer(day_number) in current_attendee.available_days do
        current_attendee.available_days -- [String.to_integer(day_number)]
      else
        [String.to_integer(day_number) | current_attendee.available_days]
      end

    MeetingServer.update_available_days(meeting.id, current_attendee, available_days)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_role", %{"attendee_id" => attendee_id}, socket)
      when is_admin(socket) do
    attendee_to_update =
      Enum.find(socket.assigns.meeting.attendees, &(to_string(&1.id) == attendee_id))

    MeetingServer.update_role(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      attendee_to_update,
      if(attendee_to_update.role == :admin, do: :user, else: :admin)
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_meeting", %{"title" => title}, socket) when is_admin(socket) do
    MeetingServer.update_meeting(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      %{title: title}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("leave", _params, socket) do
    MeetingServer.leave_meeting(socket.assigns.meeting.id, socket.assigns.current_attendee)
    {:noreply, socket}
  end

  @impl true
  def handle_event("kick", %{"attendee_id" => attendee_id}, socket) when is_admin(socket) do
    attendee_to_kick =
      Enum.find(socket.assigns.meeting.attendees, &(to_string(&1.id) === attendee_id))

    MeetingServer.kick_attendee(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      attendee_to_kick
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{}, socket) when is_admin(socket) do
    MeetingServer.delete_meeting(socket.assigns.meeting.id)
    {:noreply, socket}
  end
end
