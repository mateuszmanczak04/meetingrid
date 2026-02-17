defmodule Core.Meetings.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "invitations" do
    field :code, :string
    field :expires_at, :utc_datetime

    belongs_to :meeting, Core.Meetings.Meeting

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = invitation, attrs) do
    invitation
    |> cast(attrs, [:code, :expires_at])
    |> validate_required([:code, :expires_at])
    |> validate_expires_at_in_the_future()
  end

  defp validate_expires_at_in_the_future(changeset) do
    expires_at = get_change(changeset, :expires_at)

    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :gt -> changeset
      :lt -> add_error(changeset, :expires_at, "Invitation expiry date must be in the future")
    end
  end
end
