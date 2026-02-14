defmodule Core.Meetings.Meeting.Config.Month do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_days_amount [28, 30, 31]

  @primary_key false
  embedded_schema do
    field :days_amount, :integer
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:days_amount])
    |> validate_required([:days_amount])
    |> validate_days_amount()
  end

  defp validate_days_amount(changeset) do
    if get_change(changeset, :days_amount) in @valid_days_amount do
      changeset
    else
      add_error(
        changeset,
        :days_amount,
        "must be integer from #{inspect(@valid_days_amount)}"
      )
    end
  end
end
