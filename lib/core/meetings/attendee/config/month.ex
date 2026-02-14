defmodule Core.Meetings.Attendee.Config.Month do
  use Ecto.Schema
  import Ecto.Changeset

  @type day ::
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
          | 24
          | 25
          | 26
          | 27
          | 28
          | 29
          | 30

  @valid_available_days 0..30

  @primary_key false
  embedded_schema do
    field :available_days, {:array, :integer}, default: []
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:available_days])
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
          add_error(
            changeset,
            :available_days,
            "all must be integers from #{inspect(@valid_available_days)}"
          )
        end

      _other ->
        add_error(changeset, :available_days, "must be a list")
    end
  end
end
