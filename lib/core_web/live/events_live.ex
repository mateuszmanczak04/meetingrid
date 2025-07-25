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
      socket = socket |> assign_current_attendee() |> assign_other_attendees()
      {:noreply, socket}
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
    socket = assign_other_attendees(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{updated_attendee: _updated_attendee}, socket) do
    socket = assign_other_attendees(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{deleted_attendee: _deleted_attendee}, socket) do
    socket = assign_other_attendees(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    socket = create_and_broadcast_attendee(socket, name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("choose_day", %{"day_number" => day_number}, socket) do
    current_attendee = get_current_attendee(socket)
    day_number = String.to_integer(day_number)
    available_days = toggle_available_day(current_attendee.available_days, day_number)
    socket = update_and_broadcast_current_attendee(socket, %{available_days: available_days})
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave", _params, socket) do
    delete_and_broadcast_current_attendee(socket)
    {:noreply, assign(socket, :current_attendee, nil)}
  end

  defp subscribe_to_events(socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Core.PubSub, "event-#{socket.assigns.event.id}")
    end
  end

  defp get_current_attendee(socket) do
    if Map.get(socket.assigns, :current_attendee) do
      socket.assigns.current_attendee
    else
      Events.get_attendee_by(
        browser_id: socket.assigns.browser_id,
        event_id: socket.assigns.event.id
      )
    end
  end

  defp assign_current_attendee(socket) do
    assign(socket, :current_attendee, get_current_attendee(socket))
  end

  defp assign_other_attendees(socket) do
    event_attendees = Events.list_attendees_by(event_id: socket.assigns.event.id)
    current_attendee = get_current_attendee(socket)

    other_attendees =
      if current_attendee do
        Enum.reject(event_attendees, &(&1.id == current_attendee.id))
      else
        event_attendees
      end
      |> Enum.sort_by(& &1.name)

    assign(socket, :other_attendees, other_attendees)
  end

  defp create_and_broadcast_attendee(socket, name) do
    attendee =
      Events.create_attendee!(%{
        event_id: socket.assigns.event.id,
        browser_id: socket.assigns.browser_id,
        name: name
      })

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      new_attendee: attendee
    })

    assign(socket, :current_attendee, attendee)
  end

  defp update_and_broadcast_current_attendee(socket, attrs) do
    attendee = get_current_attendee(socket)
    attendee = Events.update_attendee!(attendee, attrs)

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      updated_attendee: attendee
    })

    assign(socket, :current_attendee, attendee)
  end

  defp delete_and_broadcast_current_attendee(socket) do
    attendee = get_current_attendee(socket)
    Events.delete_attendee!(attendee)

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      deleted_attendee: attendee
    })

    assign(socket, :current_attendee, nil)
  end

  defp toggle_available_day(available_days, day_number) do
    if day_number in available_days do
      available_days -- [day_number]
    else
      [day_number | available_days]
    end
  end
end
