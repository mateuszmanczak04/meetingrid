defmodule Core.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :title, :string, default: ""
    field :password, :string, default: nil
    has_many :attendees, Core.Events.Attendee

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :password])
    |> validate_required([])
    |> hash_password()
  end

  defp hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      put_change(changeset, :password, Argon2.hash_pwd_salt(password))
    else
      changeset
    end
  end
end
