defmodule Core.Meetings.Meeting.Config.Day do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [])
  end
end
