defmodule Core.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meetings" do
    field :title, :string

    has_many :meetings_attendees, Core.Meetings.MeetingsAttendees
    has_many :attendees, through: [:meetings_attendees, :attendee]
    has_many :invitations, Core.Meetings.Invitation

    timestamps(type: :utc_datetime)
  end

  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [:title])
    |> validate_required([])
  end
end
