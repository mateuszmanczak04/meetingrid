defmodule Core.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}
  @type id :: pos_integer()

  schema "meetings" do
    field :title, :string

    has_many :attendees, Core.Meetings.Attendee
    has_many :invitations, Core.Meetings.Invitation

    many_to_many :users, Core.Auth.User,
      join_through: Core.Meetings.Attendee,
      unique: true

    timestamps(type: :utc_datetime)
  end

  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> validate_length(:title, max: 200)
  end
end
