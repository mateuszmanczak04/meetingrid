defmodule CoreWeb.Events.IndexLive do
  use CoreWeb, :live_view
  alias Core.Events

  @impl true
  def mount(_params, %{"browser_id" => browser_id}, socket) do
    {:ok, assign(socket, :browser_id, browser_id)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    event = Events.create_event!()
    {:noreply, push_patch(socket, to: ~p"/events/#{event.id}", replace: true)}
  end
end
