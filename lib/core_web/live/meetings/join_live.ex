defmodule CoreWeb.Meetings.JoinLive do
  use CoreWeb, :live_view
  alias Core.Meetings.MeetingServer

  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :meeting_exists}
  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :user_not_joined}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("join", %{"code" => code}, socket) do
    case MeetingServer.join_meeting(socket.assigns.meeting.id, socket.assigns.current_user, code) do
      :ok -> {:noreply, push_navigate(socket, to: ~p"/meetings/#{socket.assigns.meeting.id}")}
      {:error, :invalid_code} -> {:noreply, put_flash(socket, :error, "Invalid invitation code")}
      :error -> {:noreply, put_flash(socket, :error, "Unknown error occurred")}
    end
  end
end
