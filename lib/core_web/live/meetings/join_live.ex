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
end
