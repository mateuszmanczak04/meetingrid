defmodule Core.Meetings.Attendee do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}
  @type role :: :user | :admin
  @type day :: 0 | 1 | 2 | 3 | 4 | 5 | 6

  @valid_available_days 0..6

  schema "attendees" do
    field :available_days, {:array, :integer}
    field :role, Ecto.Enum, values: [:user, :admin]

    belongs_to :meeting, Core.Meetings.Meeting, on_replace: :delete
    belongs_to :user, Core.Auth.User, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:available_days, :role])
    |> validate_required([:available_days, :role])
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
