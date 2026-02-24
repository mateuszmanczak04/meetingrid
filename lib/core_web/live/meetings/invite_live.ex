defmodule CoreWeb.Meetings.InviteLive do
  use CoreWeb, :live_view
  alias Core.Meetings

  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :meeting_exists}
  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :user_joined}
  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :user_is_admin}

  @impl true
  def mount(_params, _session, socket) do
    invitations = Meetings.list_meeting_invitations(socket.assigns.meeting)
    {:ok, assign(socket, :invitations, invitations)}
  end

  @impl true
  def handle_event("create", %{"duration" => duration}, socket) do
    case Meetings.create_invitation(socket.assigns.current_attendee, %{duration: duration}) do
      {:ok, invitation} ->
        invitations = Meetings.list_meeting_invitations(socket.assigns.meeting)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully created an invitation, code: #{invitation.code}")
         |> assign(:invitations, invitations)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Something went wrong")}
    end
  end

  @impl true
  def handle_event("revoke", %{"id" => invitation_id}, socket) do
    case Meetings.delete_invitation(socket.assigns.current_attendee, invitation_id) do
      {:ok, _} ->
        invitations = Meetings.list_meeting_invitations(socket.assigns.meeting)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully revoked an invitation")
         |> assign(:invitations, invitations)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Something went wrong")}
    end
  end
end
