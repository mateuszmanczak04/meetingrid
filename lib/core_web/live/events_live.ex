defmodule CoreWeb.EventsLive do
  use CoreWeb, :live_view
  alias Core.Events

  @impl true
  def mount(_params, %{"browser_id" => browser_id}, socket) do
    {:ok, socket |> assign(:browser_id, browser_id)}
  end

  @impl true
  def handle_params(%{"event_id" => event_id}, _uri, socket) do
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
      {:noreply, push_patch(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    event = Events.create_event!()
    {:noreply, push_patch(socket, to: ~p"/events/?event_id=#{event.id}", replace: true)}
  end

  @impl true
  def handle_info(%{new_attendee: _new_attendee}, socket) do
    {:noreply,
     socket
     |> assign_current_attendee()
     |> assign_other_attendees()
     |> assign_matching_days()}
  end

  @impl true
  def handle_info(%{updated_attendee: _updated_attendee}, socket) do
    {:noreply,
     socket
     |> assign_current_attendee()
     |> assign_other_attendees()
     |> assign_matching_days()}
  end

  @impl true
  def handle_info(%{deleted_attendee: _deleted_attendee}, socket) do
    {:noreply,
     socket
     |> assign_current_attendee()
     |> assign_other_attendees()
     |> assign_matching_days()}
  end

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    attendee =
      Events.create_attendee!(%{
        event_id: socket.assigns.event.id,
        browser_id: socket.assigns.browser_id,
        name: name
      })

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      new_attendee: attendee
    })

    {:noreply, socket}
  end

  @impl true
  def handle_event("choose_day", %{"day_number" => day_number}, socket) do
    attendee = socket.assigns.current_attendee
    available_days = toggle_available_day(attendee.available_days, String.to_integer(day_number))

    attendee =
      Events.update_attendee!(attendee, %{available_days: available_days})

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      updated_attendee: attendee
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
      deleted_attendee: attendee
    })

    {:noreply, socket}
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

  defp assign_other_attendees(socket) do
    event_attendees = Events.list_attendees_by(event_id: socket.assigns.event.id)
    current_attendee = socket.assigns.current_attendee

    other_attendees =
      if current_attendee do
        Enum.reject(event_attendees, &(&1.id == current_attendee.id))
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
