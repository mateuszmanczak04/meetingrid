defmodule Core.Meetings.Meeting.Config.Week do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :include_weekends, :boolean, default: false
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:include_weekends])
  end
end
