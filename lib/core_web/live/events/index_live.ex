defmodule CoreWeb.Events.IndexLive do
  use CoreWeb, :live_view
  alias Core.Events
  import CoreWeb.CoreComponents

  @impl true
  def mount(_params, %{"browser_id" => browser_id}, socket) do
    {:ok, assign(socket, :browser_id, browser_id)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    attendees = Events.list_attendees_by(browser_id: socket.assigns.browser_id)
    events = Enum.map(attendees, &Events.get_event(&1.event_id))
    {:noreply, assign(socket, :events, events)}
  end

  @impl true
  def handle_event("create_event", _params, socket) do
    event = Events.create_event!(%{title: "Untitled"})
    {:noreply, push_navigate(socket, to: ~p"/events/#{event.id}", replace: true)}
  end
end
