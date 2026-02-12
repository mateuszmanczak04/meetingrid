defmodule Core.Meetings.Attendee.Config.Day do
  use Ecto.Schema
  import Ecto.Changeset

  @type hour ::
          0
          | 1
          | 2
          | 3
          | 4
          | 5
          | 6
          | 7
          | 8
          | 9
          | 10
          | 11
          | 12
          | 13
          | 14
          | 15
          | 16
          | 17
          | 18
          | 19
          | 20
          | 21
          | 22
          | 23

  @valid_available_hours 0..23

  @primary_key false
  embedded_schema do
    field :mode, Ecto.Enum, values: [:day], default: :day
    field :available_hours, {:array, :integer}, default: []
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:mode, :available_hours])
    |> validate_required([])
    |> validate_available_hours()
  end

  defp validate_available_hours(changeset) do
    case get_change(changeset, :available_hours) do
      nil ->
        changeset

      hours when is_list(hours) ->
        if Enum.all?(hours, &(&1 in @valid_available_hours)) do
          changeset
        else
          add_error(changeset, :available_hours, "must be between 0 and 23")
        end

      _other ->
        add_error(changeset, :available_hours, "must be a list")
    end
  end
end
