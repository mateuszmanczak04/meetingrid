defmodule CoreWeb.Meetings.NewLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  alias Core.Auth

  @impl true
  def mount(_params, %{"user_id" => current_user_id}, socket) do
    current_user = Auth.get_user(current_user_id)
    {:ok, socket |> assign(:current_user, current_user)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
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
