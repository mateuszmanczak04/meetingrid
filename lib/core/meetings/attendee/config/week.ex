defmodule Core.Meetings.Attendee.Config.Week do
  use Ecto.Schema
  import Ecto.Changeset

  @type day :: 0 | 1 | 2 | 3 | 4 | 5 | 6

  @valid_available_days 0..6

  @primary_key false
  embedded_schema do
    field :mode, Ecto.Enum, values: [:week], default: :week
    field :available_days, {:array, :integer}, default: []
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:mode, :available_days])
    |> validate_required([])
    |> validate_available_days()
  end

  defp validate_available_days(changeset) do
    case get_change(changeset, :available_days) do
      nil ->
        changeset

      days when is_list(days) ->
        if Enum.all?(days, &(&1 in @valid_available_days)) do
          changeset
        else
          add_error(changeset, :available_days, "must be between 0 and 6")
        end

      _other ->
        add_error(changeset, :available_days, "must be a list")
    end
  end
end
