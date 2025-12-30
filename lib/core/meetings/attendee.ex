defmodule Core.Meetings.Attendee do
  use Ecto.Schema
  import Ecto.Changeset

  # Users do not register/login but are rememembered by cookies

  schema "attendees" do
    field :name, :string

    has_many :meetings_attendees, Core.Meetings.MeetingsAttendees
    has_many :meetings, through: [:meetings_attendees, :meeting]

    timestamps(type: :utc_datetime)
  end

  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
