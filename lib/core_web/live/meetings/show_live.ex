defmodule CoreWeb.Meetings.ShowLive do
  use CoreWeb, :live_view
  alias Core.Meetings.MeetingServer

  @impl true
  def mount(%{"id" => meeting_id}, %{"user" => user}, socket) do
    meeting_id = String.to_integer(meeting_id)

    case MeetingServer.check_if_already_joined(meeting_id, user) do
      {false, _state} ->
        {:ok, push_navigate(socket, to: ~p"/meetings/#{meeting_id}/join")}

      {current_attendee, state} ->
        Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{meeting_id}")
        Phoenix.PubSub.subscribe(Core.PubSub, "attendee:#{current_attendee.id}")

        {:ok,
         socket
         |> assign(:current_attendee, current_attendee)
         |> assign(:meeting, state.meeting)
         |> assign(:attendees, state.attendees)
         |> assign(:common_days, state.common_days)}
    end
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    current_attendee =
      Enum.find(
        state.attendees,
        &(&1.id === socket.assigns.current_attendee.id)
      )

    {:noreply,
     socket
     |> assign(:meeting, state.meeting)
     |> assign(:attendees, state.attendees)
     |> assign(:common_days, state.common_days)
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

  @impl true
  def handle_event("toggle_available_day", %{"day_number" => day_number}, socket) do
    MeetingServer.toggle_available_day(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      String.to_integer(day_number)
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
  def handle_event("update_meeting", %{"title" => title}, socket) do
    MeetingServer.update_meeting(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      %{title: title}
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
      Enum.find(socket.assigns.attendees, &(to_string(&1.id) === attendee_id))

    MeetingServer.kick_attendee(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee,
      attendee_to_kick
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _, socket) do
    MeetingServer.delete_meeting(
      socket.assigns.meeting.id,
      socket.assigns.current_attendee
    )

    {:noreply, socket}
  end
end
