defmodule CoreWeb.Live.Hooks.MeetingAccess do
  @moduledoc """
  Remember about proper order of hooks when stacking, that's because:
  * `:user_joined` and `:user_not_joined` depend on `:meeting_exists`
  * `:user_is_admin` depends on `:user_joined`

  These hooks also depend on `CoreWeb.Live.Hooks.UserAuth` `:require_current_user`
  """

  use CoreWeb, :verified_routes

  import Phoenix.Component
  import Phoenix.LiveView

  alias Core.Meetings

  def on_mount(:meeting_exists, %{"id" => meeting_id}, _session, socket) do
    case Meetings.get_meeting(meeting_id) do
      %Meetings.Meeting{} = meeting -> {:cont, assign(socket, :meeting, meeting)}
      nil -> {:halt, push_navigate(socket, to: ~p"/meetings")}
    end
  end

  def on_mount(:user_joined, _params, _session, socket) do
    case Meetings.check_if_already_joined(socket.assigns.current_user, socket.assigns.meeting) do
      %Meetings.Attendee{} = attendee -> {:cont, assign(socket, :current_attendee, attendee)}
      false -> {:halt, push_navigate(socket, to: ~p"/meetings/#{socket.assigns.meeting.id}/join")}
    end
  end

  def on_mount(:user_not_joined, _params, _session, socket) do
    case Meetings.check_if_already_joined(socket.assigns.current_user, socket.assigns.meeting) do
      %Meetings.Attendee{} ->
        {:halt, push_navigate(socket, to: ~p"/meetings/#{socket.assigns.meeting.id}")}

      false ->
        {:cont, socket}
    end
  end

  def on_mount(:user_is_admin, _params, _session, socket) do
    if socket.assigns.current_attendee.role == :admin do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "Only admins are allowed to do it")
       |> push_navigate(to: ~p"/meetings/#{socket.assigns.meeting.id}")}
    end
  end
end
