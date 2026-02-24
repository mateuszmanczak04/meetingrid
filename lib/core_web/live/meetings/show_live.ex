defmodule CoreWeb.Meetings.ShowLive do
  use CoreWeb, :live_view
  alias Core.Meetings.MeetingServer
  alias Core.Meetings.Meeting

  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :meeting_exists}
  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :user_joined}

  @impl true
  def mount(_params, _session, socket) do
    meeting_id = socket.assigns.meeting.id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{socket.assigns.meeting.id}")
      Phoenix.PubSub.subscribe(Core.PubSub, "attendee:#{socket.assigns.current_attendee.id}")
    end

    state = MeetingServer.get_state(meeting_id)
    {:ok, assign_state_based_on_config(socket, state)}
  end

  @impl true
  def handle_event("toggle_available_day", %{"day" => day}, socket) do
    MeetingServer.toggle_available_day(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      String.to_integer(day)
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_available_hour", %{"hour" => hour}, socket) do
    MeetingServer.toggle_available_hour(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      String.to_integer(hour)
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_attendee_role", %{"attendee_id" => attendee_id}, socket) do
    attendee_to_update =
      Enum.find(socket.assigns.attendees, &(to_string(&1.id) == attendee_id))

    MeetingServer.update_attendee_role(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      attendee_to_update,
      if(attendee_to_update.role == :admin, do: :user, else: :admin)
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("leave", _params, socket) do
    case MeetingServer.leave_meeting(
           socket.assigns.meeting.id,
           socket.assigns.current_attendee
         ) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "You've left the meeting")
         |> push_navigate(to: ~p"/meetings")}

      {:error, :last_admin_cant_leave} ->
        {:noreply,
         put_flash(socket, :error, "You can't leave the meeting while being the only admin")}

      :error ->
        {:noreply, put_flash(socket, :error, "Unknown error occurred")}
    end
  end

  @impl true
  def handle_event("kick_attendee", %{"attendee_id" => attendee_id}, socket) do
    attendee_to_kick =
      Enum.find(socket.assigns.attendees, &(to_string(&1.id) == attendee_id))

    MeetingServer.kick_attendee(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      attendee_to_kick
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    current_attendee =
      Enum.find(
        state.attendees,
        &(&1.id == socket.assigns.current_attendee.id)
      )

    {:noreply,
     socket
     |> assign_state_based_on_config(state)
     |> assign(:current_attendee, current_attendee)}
  end

  @impl true
  def handle_info(:you_were_kicked, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "You were kicked from the meeting")
     |> push_navigate(to: ~p"/meetings")}
  end

  @impl true
  def handle_info(:meeting_deleted, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "This meeting has been deleted")
     |> push_navigate(to: ~p"/meetings")}
  end

  defp assign_state_based_on_config(socket, state) do
    assign(socket,
      mode: get_mode(state.meeting.config),
      meeting: state.meeting,
      attendees: state.attendees,
      common_hours: state.common_hours,
      common_days: state.common_days
    )
  end

  defp get_mode(%Meeting.Config.Day{}), do: :day
  defp get_mode(%Meeting.Config.Week{}), do: :week
  defp get_mode(%Meeting.Config.Month{}), do: :month
end
