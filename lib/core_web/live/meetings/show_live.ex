defmodule CoreWeb.Meetings.ShowLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  alias Phoenix.LiveView.JS
  alias Core.Meetings.MeetingServer
  import CoreWeb.Meetings.Guards

  @impl true
  def mount(_params, %{"user" => user}, socket) do
    {:ok, assign(socket, :user, user)}
  end

  @impl true
  def handle_params(%{"id" => meeting_id}, _uri, socket) do
    case Meetings.get_meeting(meeting_id) do
      nil ->
        push_navigate(socket, to: ~p"/meetings")

      meeting ->
        # MeetingServer.ensure_started(meeting_id)
        Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{meeting_id}")

        current_attendee =
          case Meetings.get_attendee_by(meeting_id: meeting_id, user_id: socket.assigns.user.id) do
            nil ->
              Meetings.create_attendee!(meeting, socket.assigns.user, %{role: :user})

            attendee ->
              attendee
          end

        %MeetingServer.State{meeting: meeting, common_days: common_days} =
          MeetingServer.get_state(meeting_id)

        MeetingServer.refresh(meeting.id)

        {:noreply,
         socket
         |> assign(:current_attendee, current_attendee)
         |> assign(:meeting, meeting)
         |> assign(:common_days, common_days)}
    end
  end

  @impl true
  def handle_info(:meeting_deleted, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "This meeting has been deleted")
     |> push_navigate(to: ~p"/meetings")}
  end

  # TODO: redirect kicked user

  @impl true
  def handle_info(
        {:state_updated, %MeetingServer.State{meeting: meeting, common_days: common_days}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:meeting, meeting)
     |> assign(:common_days, common_days)}
  end

  @impl true
  def handle_event("choose_day", %{"day_number" => day_number}, socket) do
    %{user: user, meeting: meeting, current_attendee: current_attendee} = socket.assigns

    available_days =
      if String.to_integer(day_number) in current_attendee.available_days do
        current_attendee.available_days -- [String.to_integer(day_number)]
      else
        [String.to_integer(day_number) | current_attendee.available_days]
      end

    Meetings.update_attendee!(current_attendee, %{available_days: available_days})
    current_attendee = Meetings.get_attendee_by(meeting_id: meeting.id, user_id: user.id)

    MeetingServer.refresh(meeting.id)

    {:noreply, assign(socket, :current_attendee, current_attendee)}
  end

  @impl true
  def handle_event("share", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :info,
       "URL has been copied to the clipboard. You can now send it to your friend :)"
     )}
  end

  @impl true
  def handle_event("leave", _params, socket) do
    Meetings.delete_attendee!(socket.assigns.current_attendee)
    MeetingServer.refresh(socket.assigns.meeting.id)
    {:noreply, push_navigate(socket, to: ~p"/meetings")}
  end

  @impl true
  def handle_event("kick", %{"attendee_id" => attendee_id}, socket) when is_admin(socket) do
    attendee = Meetings.get_attendee_by(id: attendee_id, meeting_id: socket.assigns.meeting.id)
    Meetings.delete_attendee!(attendee)
    MeetingServer.refresh(socket.assigns.meeting.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_role", %{"attendee_id" => attendee_id}, socket)
      when is_admin(socket) do
    attendee = Meetings.get_attendee_by(id: attendee_id, meeting_id: socket.assigns.meeting.id)

    Meetings.update_attendee!(
      attendee,
      %{role: if(attendee.role == :admin, do: :user, else: :admin)}
    )

    MeetingServer.refresh(socket.assigns.meeting.id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_meeting", %{"title" => title}, socket) when is_admin(socket) do
    Meetings.update_meeting!(socket.assigns.meeting, %{title: title})
    MeetingServer.refresh(socket.assigns.meeting.id)

    {:noreply, socket}
  end

  def handle_event("delete", %{}, socket) when is_admin(socket) do
    Meetings.delete_meeting!(socket.assigns.meeting)
    {:noreply, socket}
  end
end
