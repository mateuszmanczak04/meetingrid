defmodule Core.Meetings.Attendee do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}
  @type role :: :user | :admin

  schema "attendees" do
    field :role, Ecto.Enum, values: [:user, :admin]

    field :config, Core.Meetings.Attendee.Config

    belongs_to :meeting, Core.Meetings.Meeting, on_replace: :delete
    belongs_to :user, Core.Auth.User, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = attendee, attrs) do
    attendee
    |> cast(attrs, [:role, :config])
    |> validate_required([:role, :config])
  end
end
