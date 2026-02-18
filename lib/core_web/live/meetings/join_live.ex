defmodule CoreWeb.Meetings.JoinLive do
  use CoreWeb, :live_view
  alias Core.Meetings.MeetingServer

  @impl true
  def mount(%{"id" => meeting_id}, %{"user" => user}, socket) do
    meeting_id = String.to_integer(meeting_id)

    case MeetingServer.check_if_already_joined(meeting_id, user) do
      {false, state} ->
        Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{meeting_id}")
        {:ok, socket |> assign(:meeting, state.meeting) |> assign(:user, user)}

      {_, _} ->
        {:ok, push_navigate(socket, to: ~p"/meetings/#{meeting_id}")}
    end
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    {:noreply, assign(socket, :meeting, state.meeting)}
  end

  @impl true
  def handle_info(:meeting_deleted, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "This meeting has been deleted")
     |> push_navigate(to: ~p"/meetings")}
  end

  @impl true
  def handle_event("join", %{"code" => code}, socket) do
    case MeetingServer.join_meeting(socket.assigns.meeting.id, socket.assigns.user, code) do
      :ok -> {:noreply, push_navigate(socket, to: ~p"/meetings/#{socket.assigns.meeting.id}")}
      {:error, :invalid_code} -> {:noreply, put_flash(socket, :error, "Invalid invitation code")}
      :error -> {:noreply, put_flash(socket, :error, "Unknown error occurred")}
    end
  end
end
