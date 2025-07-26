defmodule Core.Events.Attendee do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "attendees" do
    field :name, :string, default: ""
    field :browser_id, :string, primary_key: true
    field :available_days, {:array, :integer}, default: []
    belongs_to :event, Core.Events.Event, primary_key: true

    timestamps(type: :utc_datetime)
  end

  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:event_id, :name, :available_days, :browser_id])
    |> validate_required([:event_id, :browser_id])
  end
end
