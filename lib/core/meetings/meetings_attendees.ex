defmodule Core.Meetings.MeetingsAttendees do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meetings_attendees" do
    field :available_days, {:array, :integer}, default: []
    field :role, Ecto.Enum, values: [:user, :admin], default: :user

    belongs_to :meeting, Core.Meetings.Meeting, on_replace: :delete
    belongs_to :attendee, Core.Meetings.Attendee, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(meetings_attendees, attrs) do
    meetings_attendees
    |> cast(attrs, [:available_days, :role, :meeting_id, :attendee_id])
    |> validate_required([:available_days, :role, :meeting_id, :attendee_id])
    |> assoc_constraint(:meeting)
    |> assoc_constraint(:attendee)
  end
end
