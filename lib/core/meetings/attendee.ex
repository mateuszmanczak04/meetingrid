defmodule Core.Meetings.Attendee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attendees" do
    field :available_days, {:array, :integer}, default: []
    field :role, Ecto.Enum, values: [:user, :admin], default: :user

    belongs_to :meeting, Core.Meetings.Meeting, on_replace: :delete
    belongs_to :user, Core.Auth.User, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:available_days, :role])
    |> validate_required([:available_days, :role])
    |> assoc_constraint(:meeting)
    |> assoc_constraint(:user)
  end
end
