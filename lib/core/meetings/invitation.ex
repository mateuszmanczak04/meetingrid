defmodule Core.Meetings.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invitations" do
    field :code, :string
    field :role, Ecto.Enum, values: [:user, :admin], default: :user

    belongs_to :meeting, Core.Meetings.Meeting, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:meeting_id, :code, :role])
    |> validate_required([:meeting_id, :code, :role])
    |> assoc_constraint(:meeting)
  end
end
