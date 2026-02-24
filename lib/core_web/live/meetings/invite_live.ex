defmodule CoreWeb.Meetings.InviteLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  alias Core.Meetings.Meeting

  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :meeting_exists}
  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :user_joined}
  on_mount {CoreWeb.Live.Hooks.MeetingAccess, :user_is_admin}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{socket.assigns.meeting.id}")
      Phoenix.PubSub.subscribe(Core.PubSub, "attendee:#{socket.assigns.current_attendee.id}")
    end

    # In case of later adding more options to invitations, it may be
    # worth to replace schemaless changeset with regular one
    data = %{}
    types = %{duration: :binary}
    params = %{duration: "day"}

    form =
      {data, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))
      |> Ecto.Changeset.validate_required(Map.keys(types))
      |> to_form(as: :invitation)

    invitations = Meetings.list_meeting_invitations(socket.assigns.meeting)
    {:ok, assign(socket, invitations: invitations, form: form)}
  end

  @impl true
  def handle_event("create", %{"invitation" => attrs}, socket) do
    case Meetings.create_invitation(socket.assigns.current_attendee, attrs) do
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
  def handle_info(:you_were_kicked, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "You were kicked from the meeting")
     |> push_navigate(to: ~p"/meetings")}
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
