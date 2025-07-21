defmodule Core.Events do
  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Events.Event
  alias Core.Events.Attendee

  # EVENTS

  def get_event(id), do: Repo.get(Event, id)

  def create_event!(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert!()
  end

  # ATTENDEES

  def get_attendee_by(clauses), do: Repo.get_by(Attendee, clauses)
  def list_attendees_by(clauses), do: Repo.all_by(Attendee, clauses)

  def create_attendee!(attrs \\ %{}) do
    %Attendee{}
    |> Attendee.changeset(attrs)
    |> Repo.insert!()
  end

  def update_attendee!(%Attendee{} = attendee, attrs) do
    attendee
    |> Attendee.changeset(attrs)
    |> Repo.update!()
  end
end
