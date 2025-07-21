defmodule Core.EventsTest do
  use Core.DataCase

  alias Core.Events

  describe "events" do
    alias Core.Events.Event

    import Core.EventsFixtures

    test "get_event/1 returns the event with given id" do
      event = event_fixture()
      assert Events.get_event(event.id) == event
    end

    test "create_event!/1 with valid data creates a event" do
      valid_attrs = %{title: "some title"}

      assert %Event{} = event = Events.create_event!(valid_attrs)
      assert event.title == "some title"
    end
  end

  describe "attendees" do
    alias Core.Events.Attendee

    import Core.EventsFixtures

    setup do
      event = event_fixture()
      [event: event]
    end

    test "get_attendee_by/1 browser_id and event_id returns attendee", %{event: event} do
      browser_id = "123456"

      attendee = attendee_fixture(%{browser_id: browser_id, event_id: event.id})

      assert Events.get_attendee_by(browser_id: browser_id, event_id: event.id) == attendee
    end

    test "list_attendees_by/1 event_id returns attendees", %{event: event} do
      attendee1 = attendee_fixture(%{event_id: event.id, browser_id: "browser_id1"})
      attendee2 = attendee_fixture(%{event_id: event.id, browser_id: "browser_id2"})
      attendee3 = attendee_fixture(%{event_id: event.id, browser_id: "browser_id3"})

      assert Events.list_attendees_by(event_id: event.id) == [attendee1, attendee2, attendee3]
    end

    test "create_attendee!/1 with valid data creates an attendee", %{event: event} do
      name = "some name"
      available_days = [1, 2]
      browser_id = "some_browser_id"

      assert %Attendee{} =
               attendee =
               Events.create_attendee!(%{
                 name: name,
                 available_days: available_days,
                 event_id: event.id,
                 browser_id: browser_id
               })

      assert attendee.name == name
      assert attendee.available_days == available_days
      assert attendee.event_id == event.id
      assert attendee.browser_id == browser_id
    end

    test "update_attendee!/2 with valid data updates the attendee", %{event: event} do
      attendee = attendee_fixture(%{event_id: event.id})
      new_name = "some updated name"
      new_available_days = [1]

      assert %Attendee{} =
               attendee =
               Events.update_attendee!(attendee, %{
                 name: new_name,
                 available_days: new_available_days
               })

      assert attendee.name == new_name
      assert attendee.available_days == new_available_days
    end
  end
end
