defmodule Core.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  # Users do not register/login but are remembered by cookies

  schema "users" do
    field :name, :string

    has_many :attendees, Core.Meetings.Attendee

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
