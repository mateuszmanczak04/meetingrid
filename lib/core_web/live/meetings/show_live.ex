defmodule CoreWeb.Meetings.ShowLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, %{"user" => user}, socket) do
    {:ok, assign(socket, :user, user)}
  end

  @impl true
  def handle_params(%{"id" => meeting_id}, _uri, socket) do
    # Assume attendee is present here (for now automatically create them)

    current_attendee =
      Meetings.get_attendee_by(
        [meeting_id: meeting_id, user_id: socket.assigns.user.id],
        preload: [meeting: [attendees: :user]]
      )

    current_attendee =
      if current_attendee do
        current_attendee
      else
        meeting = Meetings.get_meeting(meeting_id)
        Meetings.add_attendee_to_meeting!(meeting, socket.assigns.user)

        Meetings.get_attendee_by(
          meeting_id: meeting_id,
          user_id: socket.assigns.user.id
        )
      end
      |> Core.Repo.preload(meeting: [attendees: :user])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Core.PubSub, "meeting-#{current_attendee.meeting.id}")
    end

    socket =
      socket
      |> assign(:current_attendee, current_attendee)
      |> assign(:meeting, current_attendee.meeting)
      #  TODO: calculate common days
      |> assign(:common_days, [])

    broadcast(socket, :attendee)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:attendee, socket) do
    current_attendee =
      socket.assigns.current_attendee
      |> Core.Repo.reload()
      |> Core.Repo.preload(meeting: [attendees: :user])

    common_days =
      current_attendee.meeting.attendees
      |> Enum.map(& &1.available_days)
      |> Enum.map(&MapSet.new/1)
      |> Enum.reduce(&MapSet.intersection/2)
      |> MapSet.to_list()

    dbg(common_days)

    {:noreply,
     socket
     |> assign(:current_attendee, current_attendee)
     |> assign(:meeting, current_attendee.meeting)
     |> assign(:common_days, common_days)}
  end

  @impl true
  def handle_info(:delete, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "This meeting has been deleted")
     |> push_navigate(to: ~p"/meetings")}
  end

  @impl true
  def handle_info(%{meeting: meeting}, socket) do
    {:noreply, assign(socket, :meeting, meeting)}
  end

  @impl true
  def handle_event("choose_day", %{"day_number" => day_number}, socket) do
    attendee = socket.assigns.current_attendee

    available_days =
      if String.to_integer(day_number) in attendee.available_days do
        attendee.available_days -- [String.to_integer(day_number)]
      else
        [String.to_integer(day_number) | attendee.available_days]
      end

    Meetings.update_attendee!(attendee, %{available_days: available_days})
    broadcast(socket, :attendee)
    {:noreply, socket}
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
    attendee = socket.assigns.current_attendee
    Meetings.delete_attendee!(attendee)
    broadcast(socket, :attendee)
    {:noreply, push_navigate(socket, to: ~p"/meetings")}
  end

  @impl true
  def handle_event("kick", %{"attendee_id" => attendee_id}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      attendee = Meetings.get_attendee_by(id: attendee_id, meeting_id: socket.assigns.meeting.id)
      Meetings.delete_attendee!(attendee)
      broadcast(socket, :attendee)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_role", %{"attendee_id" => attendee_id}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      attendee = Meetings.get_attendee_by(id: attendee_id, meeting_id: socket.assigns.meeting.id)

      Meetings.update_attendee!(
        attendee,
        %{role: if(attendee.role == :admin, do: :user, else: :admin)}
      )

      broadcast(socket, :attendee)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_meeting", %{"title" => title}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      meeting = Meetings.update_meeting!(socket.assigns.meeting, %{title: title})
      broadcast(socket, %{meeting: meeting})
    end

    {:noreply, socket}
  end

  def handle_event("delete", %{}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      Meetings.delete_meeting!(socket.assigns.meeting)
      broadcast(socket, :delete)
      {:noreply, socket}
    end
  end

  defp broadcast(socket, payload) do
    Phoenix.PubSub.broadcast(
      Core.PubSub,
      "meeting-#{socket.assigns.meeting.id}",
      payload
    )
  end
end
