defmodule Core.Events.Attendee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attendees" do
    field :name, :string, default: ""
    field :browser_id, :string
    field :available_days, {:array, :integer}, default: []
    belongs_to :event, Core.Events.Event

    timestamps(type: :utc_datetime)
  end

  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:event_id, :name, :available_days, :browser_id])
    |> validate_required([:event_id, :browser_id])
  end
end
