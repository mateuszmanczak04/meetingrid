defmodule Core.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  # Users do not register/login but are remembered by cookies

  @type t :: %__MODULE__{}
  @type id :: pos_integer()

  schema "users" do
    field :name, :string

    has_many :attendees, Core.Meetings.Attendee

    many_to_many :meetings, Core.Meetings.Meeting,
      join_through: Core.Meetings.Attendee,
      unique: true

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
  end
end
