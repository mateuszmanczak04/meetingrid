defmodule Core.Meetings.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "invitations" do
    field :code, :string
    field :role, Ecto.Enum, values: [:user, :admin], default: :user

    belongs_to :meeting, Core.Meetings.Meeting, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def create_changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:code, :role])
    |> validate_required([:code, :role])
  end

  def update_changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:code, :role])
  end
end
