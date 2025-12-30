defmodule CoreWeb.Meetings.ShowLive do
  use CoreWeb, :live_view
  alias Core.Meetings
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, %{"browser_id" => browser_id}, socket) do
    {:ok, assign(socket, :browser_id, browser_id)}
  end

  @impl true
  def handle_params(%{"id" => meeting_id}, _uri, socket) do
    meeting = Meetings.get_meeting(String.to_integer(meeting_id))

    if meeting do
      socket = assign(socket, :meeting, meeting)
      subscribe_to_meetings(socket)

      {:noreply,
       socket
       |> assign_current_attendee()
       |> assign_other_attendees()
       |> assign_matching_days()}
    else
      {:noreply, push_navigate(socket, to: ~p"/meetings", replace: true)}
    end
  end

  @impl true
  def handle_info(%{attendee: _attendee}, socket) do
    {:noreply,
     socket
     |> refresh_meeting()
     |> assign_current_attendee()
     |> assign_other_attendees()
     |> assign_matching_days()}
  end

  @impl true
  def handle_info(%{meeting: :delete}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "This meeting has been deleted")
     |> push_navigate(to: ~p"/meetings")}
  end

  @impl true
  def handle_info(%{meeting: meeting}, socket) do
    {:noreply, assign(socket, :meeting, meeting)}
  end

  @impl true
  def handle_event("join", %{"name" => name} = params, socket) do
    case {socket.assigns.meeting.password,
          params["password"] &&
            Argon2.verify_pass(params["password"], socket.assigns.meeting.password)} do
      {password, verified} when is_nil(password) or (is_binary(password) and verified) ->
        attendee =
          Meetings.create_attendee!(%{
            meeting_id: socket.assigns.meeting.id,
            browser_id: socket.assigns.browser_id,
            name: name,
            role:
              if(
                Enum.empty?(socket.assigns.meeting.attendees) &&
                  is_nil(socket.assigns.meeting.password),
                do: :admin,
                else: :user
              )
          })

        Phoenix.PubSub.broadcast(Core.PubSub, "meeting-#{socket.assigns.meeting.id}", %{
          attendee: attendee
        })

        {:noreply, socket}

      {password, false} when is_binary(password) ->
        {:noreply, put_flash(socket, :error, "Wrong password")}
    end
  end

  @impl true
  def handle_event("update_attendee", %{"name" => name}, socket) do
    attendee = Meetings.update_attendee!(socket.assigns.current_attendee, %{name: name})

    Phoenix.PubSub.broadcast(Core.PubSub, "meeting-#{socket.assigns.meeting.id}", %{
      attendee: attendee
    })

    {:noreply, socket}
  end

  @impl true
  def handle_event("choose_day", %{"day_number" => day_number}, socket) do
    attendee = socket.assigns.current_attendee
    available_days = toggle_available_day(attendee.available_days, String.to_integer(day_number))

    attendee = Meetings.update_attendee!(attendee, %{available_days: available_days})

    Phoenix.PubSub.broadcast(Core.PubSub, "meeting-#{socket.assigns.meeting.id}", %{
      attendee: attendee
    })

    {:noreply, socket}
  end

  @impl true
  def handle_event("share", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :info,
       "URL has been copied to the clipboard. You can now send it to your friend :)"
     )}
  end

  @impl true
  def handle_event("leave", _params, socket) do
    attendee = socket.assigns.current_attendee
    Meetings.delete_attendee!(attendee)

    Phoenix.PubSub.broadcast(Core.PubSub, "meeting-#{socket.assigns.meeting.id}", %{
      attendee: attendee
    })

    {:noreply, push_navigate(socket, to: ~p"/meetings")}
  end

  @impl true
  def handle_event("kick", %{"browser_id" => browser_id}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      attendee = Enum.find(socket.assigns.other_attendees, &(&1.browser_id == browser_id))
      Meetings.delete_attendee!(attendee)

      Phoenix.PubSub.broadcast(Core.PubSub, "meeting-#{socket.assigns.meeting.id}", %{
        attendee: attendee
      })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_role", %{"role" => role, "browser_id" => browser_id}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      attendee = Enum.find(socket.assigns.other_attendees, &(&1.browser_id == browser_id))
      attendee = Meetings.update_attendee!(attendee, %{role: role})

      Phoenix.PubSub.broadcast(Core.PubSub, "meeting-#{socket.assigns.meeting.id}", %{
        attendee: attendee
      })
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_meeting", %{"title" => title}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      meeting = Meetings.update_meeting!(socket.assigns.meeting, %{title: title})

      Phoenix.PubSub.broadcast(Core.PubSub, "meeting-#{socket.assigns.meeting.id}", %{
        meeting: meeting
      })
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_meeting_password", %{"password" => password}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      meeting = Meetings.update_meeting!(socket.assigns.meeting, %{password: password})

      Phoenix.PubSub.broadcast(Core.PubSub, "meeting-#{socket.assigns.meeting.id}", %{
        meeting: meeting
      })

      {:noreply, socket |> put_flash(:info, "Successfully updated meeting password")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete", %{}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      Meetings.delete_meeting!(socket.assigns.meeting)

      Phoenix.PubSub.broadcast(Core.PubSub, "meeting-#{socket.assigns.meeting.id}", %{
        meeting: :delete
      })

      {:noreply, socket}
    end
  end

  defp subscribe_to_meetings(socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Core.PubSub, "meeting-#{socket.assigns.meeting.id}")
    end
  end

  defp assign_current_attendee(socket) do
    attendee =
      Meetings.get_attendee_by(
        browser_id: socket.assigns.browser_id,
        meeting_id: socket.assigns.meeting.id
      )

    assign(socket, :current_attendee, attendee)
  end

  defp refresh_meeting(socket) do
    meeting = Meetings.get_meeting(socket.assigns.meeting.id)
    assign(socket, :meeting, meeting)
  end

  defp assign_other_attendees(socket) do
    meeting_attendees = socket.assigns.meeting.attendees
    current_attendee = socket.assigns.current_attendee

    other_attendees =
      if current_attendee do
        Enum.reject(meeting_attendees, &(&1.browser_id == current_attendee.browser_id))
      else
        meeting_attendees
      end
      |> Enum.sort_by(& &1.name)

    assign(socket, :other_attendees, other_attendees)
  end

  defp assign_matching_days(socket) do
    matching_days =
      socket.assigns
      |> Map.take([:other_attendees, :current_attendee])
      |> Map.values()
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> []
        attendees -> find_matching_days(attendees)
      end

    assign(socket, :matching_days, matching_days)
  end

  defp find_matching_days(attendees) do
    Enum.filter(0..6, fn day ->
      Enum.all?(attendees, &(day in &1.available_days))
    end)
  end

  defp toggle_available_day(available_days, day_number) do
    if day_number in available_days do
      available_days -- [day_number]
    else
      [day_number | available_days]
    end
  end
end
