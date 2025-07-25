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

      current_attendee = get_current_attendee(socket)
      other_attendees = list_other_attendees(socket) |> sort_attendees()

      {:noreply,
       socket
       |> assign(:current_attendee, current_attendee)
       |> assign(:other_attendees, other_attendees)}
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
  def handle_info(%{new_attendee: new_attendee}, socket) do
    is_current_attendee? = new_attendee.id == socket.assigns.current_attendee.id
    already_exists? = new_attendee.id in Enum.map(socket.assigns.other_attendees, & &1.id)

    other_attendees =
      if is_current_attendee? or already_exists? do
        socket.assigns.other_attendees
      else
        [new_attendee | socket.assigns.other_attendees]
      end
      |> sort_attendees()

    {:noreply, socket |> assign(:other_attendees, other_attendees)}
  end

  @impl true
  def handle_info(%{updated_attendee: updated_attendee}, socket) do
    other_attendees =
      socket.assigns.other_attendees
      |> update_within_attendees(updated_attendee)
      |> sort_attendees()

    {:noreply, socket |> assign(:other_attendees, other_attendees)}
  end

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    {:noreply, assign(socket, :current_attendee, create_and_broadcast_attendee(socket, name))}
  end

  @impl true
  def handle_event("choose_day", %{"day_number" => day_number}, socket) do
    current_attendee = socket.assigns.current_attendee
    day_number = String.to_integer(day_number)
    available_days = toggle_available_day(current_attendee.available_days, day_number)

    current_attendee =
      update_and_broadcast_attendee(socket, current_attendee, %{available_days: available_days})

    {:noreply, assign(socket, :current_attendee, current_attendee)}
  end

  defp subscribe_to_events(socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Core.PubSub, "event-#{socket.assigns.event.id}")
    end
  end

  defp get_current_attendee(socket) do
    Events.get_attendee_by(
      browser_id: socket.assigns.browser_id,
      event_id: socket.assigns.event.id
    )
  end

  defp list_other_attendees(socket) do
    event_attendees = Events.list_attendees_by(event_id: socket.assigns.event.id)
    current_attendee = get_current_attendee(socket)

    if current_attendee do
      Enum.reject(event_attendees, &(&1.id == current_attendee.id))
    else
      event_attendees
    end
  end

  defp create_and_broadcast_attendee(socket, name) do
    attendee =
      Events.create_attendee!(%{
        event_id: socket.assigns.event.id,
        browser_id: socket.assigns.browser_id,
        name: name,
        available_days: []
      })

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      new_attendee: attendee
    })

    attendee
  end

  defp update_and_broadcast_attendee(socket, attendee, attrs) do
    attendee = Events.update_attendee!(attendee, attrs)

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      updated_attendee: attendee
    })

    attendee
  end

  defp sort_attendees(attendees) do
    Enum.sort_by(attendees, & &1.name)
  end

  defp update_within_attendees(attendees, attendee) do
    Enum.map(
      attendees,
      &if(&1.id == attendee.id, do: attendee, else: &1)
    )
  end

  defp toggle_available_day(available_days, day_number) do
    if day_number in available_days do
      available_days -- [day_number]
    else
      [day_number | available_days]
    end
  end
end
