defmodule Core.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meetings" do
    field :title, :string

    has_many :attendees, Core.Meetings.Attendee
    has_many :invitations, Core.Meetings.Invitation

    timestamps(type: :utc_datetime)
  end

  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [:title])
    |> validate_required([])
  end
end
