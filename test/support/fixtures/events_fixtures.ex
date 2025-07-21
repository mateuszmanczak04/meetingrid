defmodule Core.EventsFixtures do
  def event_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "some title"
    })
    |> Core.Events.create_event!()
  end

  def attendee_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      available_days: [1, 2],
      name: "some name",
      browser_id: "some browser_id"
    })
    |> Core.Events.create_attendee!()
  end
end
