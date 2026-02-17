defmodule CoreWeb.Meetings.InviteLive do
  use CoreWeb, :live_view
  alias Core.Meetings

  @impl true
  def mount(%{"id" => meeting_id}, %{"user" => current_user}, socket) do
    meeting = Meetings.get_meeting(meeting_id, preload: [:invitations])

    case Meetings.check_if_already_joined(current_user, meeting) do
      false ->
        {:ok, push_navigate(socket, to: ~p"/meetings")}

      %{role: :admin} = current_attendee ->
        invitations = Meetings.get_meeting_invitations(meeting)

        {:ok,
         socket
         |> assign(:meeting, meeting)
         |> assign(:current_attendee, current_attendee)
         |> assign(:invitations, invitations)}

      %{role: :user} = _current_attendee ->
        {:ok,
         socket
         |> put_flash(:error, "No permission")
         |> push_navigate(to: ~p"/meetings/#{meeting_id}")}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("create", %{"duration" => duration}, socket) do
    case Meetings.create_invitation(socket.assigns.current_attendee, %{duration: duration}) do
      {:ok, invitation} ->
        invitations = Meetings.get_meeting_invitations(socket.assigns.meeting)

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
    case Meetings.revoke_invitation(socket.assigns.current_attendee, invitation_id) do
      {:ok, _} ->
        invitations = Meetings.get_meeting_invitations(socket.assigns.meeting)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully revoked an invitation")
         |> assign(:invitations, invitations)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Something went wrong")}
    end
  end
end
