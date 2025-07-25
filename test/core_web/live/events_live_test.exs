defmodule CoreWeb.EventsLiveViewTest do
  use CoreWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Core.EventsFixtures
  alias Core.Events

  setup do
    event = event_fixture()
    [event: event]
  end

  test "receives pubsub event when new attendee joins and updates their days", %{
    conn: conn,
    event: event
  } do
    {:ok, view, _html} = live(conn, "/events?event_id=#{event.id}")

    new_attendee = attendee_fixture(%{browser_id: "some browser id", event_id: event.id})
    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{event.id}", %{new_attendee: new_attendee})

    assert has_element?(view, "tr", "You")
    assert has_element?(view, "tr[data-attendee='#{new_attendee.id}']")

    available_days = [1, 2]
    updated_attendee = Events.update_attendee!(new_attendee, %{available_days: available_days})

    Phoenix.PubSub.broadcast(Core.PubSub, "event-#{event.id}", %{
      updated_attendee: updated_attendee
    })

    for day_number <- available_days do
      assert has_element?(
               view,
               "tr[data-attendee='#{updated_attendee.id}'] > td[data-day='#{day_number}'][data-selected='true']"
             )
    end
  end
end
