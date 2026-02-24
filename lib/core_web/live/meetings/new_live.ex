defmodule CoreWeb.Meetings.NewLive do
  use CoreWeb, :live_view
  alias Core.Meetings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("create", params, socket) do
    case Meetings.create_meeting(socket.assigns.current_user, params) do
      {:ok, attendee} ->
        {:noreply, push_navigate(socket, to: ~p"/meetings/#{attendee.meeting.id}")}

      {:error, _} ->
        # Basic HTML validations shouldn't allow to even get here
        {:noreply, put_flash(socket, :error, "Something went wrong. Please try again")}
    end
  end
end
