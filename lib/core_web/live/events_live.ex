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
      current_attendee = get_or_create_current_attendee(event.id, socket.assigns.browser_id)

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
  def handle_event("choose_day", %{"day_number" => day_number}, socket) do
    # TODO: send push events to other room members
    # TODO: create attendee only after first day selection

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
