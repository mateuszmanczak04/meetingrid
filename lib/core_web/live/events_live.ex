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

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Core.PubSub, "event-#{event_id}")
    end

    if event do
      current_attendee = get_or_create_current_attendee(event.id, socket.assigns.browser_id)

      Phoenix.PubSub.broadcast(Core.PubSub, "event-#{event_id}", %{
        new_attendee: current_attendee
      })

      other_attendees =
        Events.list_attendees_by(event_id: event.id)
        |> Enum.reject(&(&1.id == current_attendee.id))

      {:noreply,
       socket
       |> assign(:event, event)
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
    current_attendee? = new_attendee.id == socket.assigns.current_attendee.id
    already_exists? = new_attendee.id in Enum.map(socket.assigns.other_attendees, & &1.id)

    other_attendees =
      if current_attendee? or already_exists? do
        socket.assigns.other_attendees
      else
        [new_attendee | socket.assigns.other_attendees]
      end

    {:noreply, socket |> assign(:other_attendees, other_attendees)}
  end

  @impl true
  def handle_info(%{updated_attendee: updated_attendee}, socket) do
    other_attendees =
      Enum.map(
        socket.assigns.other_attendees,
        &if(&1.id == updated_attendee.id, do: updated_attendee, else: &1)
      )

    {:noreply, socket |> assign(:other_attendees, other_attendees)}
  end

  @impl true
  def handle_event("choose_day", %{"day_number" => day_number}, socket) do
    %{available_days: available_days} = current_attendee = socket.assigns.current_attendee

    day_number = String.to_integer(day_number)

    available_days =
      if day_number in available_days do
        List.delete(available_days, day_number)
      else
        [day_number | available_days]
      end

    current_attendee =
      Events.update_attendee!(current_attendee, %{available_days: available_days})

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{socket.assigns.event.id}", %{
      updated_attendee: current_attendee
    })

    {:noreply, socket |> assign(:current_attendee, current_attendee)}
  end

  defp get_or_create_current_attendee(event_id, browser_id) do
    if at = Events.get_attendee_by(event_id: event_id, browser_id: browser_id) do
      at
    else
      Events.create_attendee!(%{
        event_id: event_id,
        browser_id: browser_id,
        name: "User",
        available_days: []
      })
    end
  end
end
