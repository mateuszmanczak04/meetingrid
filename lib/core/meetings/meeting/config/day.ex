defmodule Core.Meetings.Meeting.Config.Day do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :mode, Ecto.Enum, values: [:day], default: :day
    field :date, :date
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:mode, :date])
    |> validate_required([:mode, :date])
  end
end
