defmodule Core.Meetings.Meeting.Config.Week do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :mode, Ecto.Enum, values: [:week], default: :week
    field :include_weekends, :boolean
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:mode, :include_weekends])
    |> validate_required([:mode, :include_weekends])
  end
end
