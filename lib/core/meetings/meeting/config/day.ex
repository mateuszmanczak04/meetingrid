defmodule Core.Meetings.Meeting.Config.Day do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :mode, Ecto.Enum, values: [:day], default: :day
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:mode])
    |> validate_required([:mode])
  end
end
