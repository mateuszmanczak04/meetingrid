defmodule CoreWeb.Meetings.JoinLive do
  use CoreWeb, :live_view
  alias Core.Meetings.MeetingServer
  alias Core.Meetings.Meeting

  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :meeting_exists}
  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :user_not_joined}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{socket.assigns.meeting.id}")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"code" => code}, _uri, socket) do
    {:noreply, do_join(socket, code)}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("join", %{"code" => code}, socket) do
    {:noreply, do_join(socket, code)}
  end

  defp do_join(socket, code) do
    case MeetingServer.join_meeting(socket.assigns.meeting.id, socket.assigns.current_user, code) do
      :ok -> push_navigate(socket, to: ~p"/meetings/#{socket.assigns.meeting.id}")
      {:error, :invalid_code} -> put_flash(socket, :error, "Invalid invitation code")
      :error -> put_flash(socket, :error, "Unknown error occurred")
    end
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
