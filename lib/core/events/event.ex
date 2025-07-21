defmodule Core.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :title, :string, default: ""
    has_many :attendee, Core.Events.Attendee

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title])
    |> validate_required([])
  end
end
