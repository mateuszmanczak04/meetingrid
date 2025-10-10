defmodule CoreWeb.Events.ShowLive do
  use CoreWeb, :live_view
  alias Core.Events
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, %{"browser_id" => browser_id}, socket) do
    {:ok, assign(socket, :browser_id, browser_id)}
  end

  @impl true
  def handle_params(%{"id" => event_id}, _uri, socket) do
    event = Events.get_event(String.to_integer(event_id))

    if event do
      socket = assign(socket, :event, event)
      subscribe_to_events(socket)

      {:noreply,
       socket
       |> assign_current_attendee()
       |> assign_other_attendees()
       |> assign_matching_days()}
    else
      {:noreply, push_navigate(socket, to: ~p"/events", replace: true)}
    end
  end

  @impl true
  def handle_info(%{attendee: _attendee}, socket) do
    {:noreply,
     socket
     |> refresh_event()
     |> assign_current_attendee()
     |> assign_other_attendees()
     |> assign_matching_days()}
  end

  @impl true
  def handle_info(%{event: :delete}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "This event has been deleted")
     |> push_navigate(to: ~p"/events")}
  end

  @impl true
  def handle_info(%{event: event}, socket) do
    {:noreply, assign(socket, :event, event)}
  end

  @impl true
  def handle_event("join", %{"name" => name} = params, socket) do
    case {socket.assigns.event.password,
          params["password"] &&
            Argon2.verify_pass(params["password"], socket.assigns.event.password)} do
      {password, verified} when is_nil(password) or (is_binary(password) and verified) ->
        attendee =
          Events.create_attendee!(%{
            event_id: socket.assigns.event.id,
            browser_id: socket.assigns.browser_id,
            name: name,
            role:
              if(
                Enum.empty?(socket.assigns.event.attendees) &&
                  is_nil(socket.assigns.event.password),
                do: :admin,
                else: :user
              )
          })

        Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
          attendee: attendee
        })

        {:noreply, socket}

      {password, false} when is_binary(password) ->
        {:noreply, put_flash(socket, :error, "Wrong password")}
    end
  end

  @impl true
  def handle_event("update_attendee", %{"name" => name}, socket) do
    attendee = Events.update_attendee!(socket.assigns.current_attendee, %{name: name})

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      attendee: attendee
    })

    {:noreply, socket}
  end

  @impl true
  def handle_event("choose_day", %{"day_number" => day_number}, socket) do
    attendee = socket.assigns.current_attendee
    available_days = toggle_available_day(attendee.available_days, String.to_integer(day_number))

    attendee = Events.update_attendee!(attendee, %{available_days: available_days})

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
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
    Events.delete_attendee!(attendee)

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      attendee: attendee
    })

    {:noreply, push_navigate(socket, to: ~p"/events")}
  end

  @impl true
  def handle_event("kick", %{"browser_id" => browser_id}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      attendee = Enum.find(socket.assigns.other_attendees, &(&1.browser_id == browser_id))
      Events.delete_attendee!(attendee)

      Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
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
      attendee = Events.update_attendee!(attendee, %{role: role})

      Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
        attendee: attendee
      })
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_event", %{"title" => title}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      event = Events.update_event!(socket.assigns.event, %{title: title})

      Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
        event: event
      })
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_event_password", %{"password" => password}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      event = Events.update_event!(socket.assigns.event, %{password: password})

      Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
        event: event
      })

      {:noreply, socket |> put_flash(:info, "Successfully updated event password")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete", %{}, socket) do
    if socket.assigns.current_attendee.role == :admin do
      Events.delete_event!(socket.assigns.event)

      Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
        event: :delete
      })

      {:noreply, socket}
    end
  end

  defp subscribe_to_events(socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Core.PubSub, "event-#{socket.assigns.event.id}")
    end
  end

  defp assign_current_attendee(socket) do
    attendee =
      Events.get_attendee_by(
        browser_id: socket.assigns.browser_id,
        event_id: socket.assigns.event.id
      )

    assign(socket, :current_attendee, attendee)
  end

  defp refresh_event(socket) do
    event = Events.get_event(socket.assigns.event.id)
    assign(socket, :event, event)
  end

  defp assign_other_attendees(socket) do
    event_attendees = socket.assigns.event.attendees
    current_attendee = socket.assigns.current_attendee

    other_attendees =
      if current_attendee do
        Enum.reject(event_attendees, &(&1.browser_id == current_attendee.browser_id))
      else
        event_attendees
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
