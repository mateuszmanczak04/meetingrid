defmodule Core.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset
  import PolymorphicEmbed

  @type t :: %__MODULE__{}
  @type id :: pos_integer()

  schema "meetings" do
    field :title, :string

    polymorphic_embeds_one(:config,
      types: [
        day: Core.Meetings.Meeting.Config.Day,
        week: Core.Meetings.Meeting.Config.Week,
        month: Core.Meetings.Meeting.Config.Month
      ],
      type_field_name: :mode,
      on_type_not_found: :raise,
      on_replace: :update
    )

    has_many :attendees, Core.Meetings.Attendee
    has_many :invitations, Core.Meetings.Invitation

    many_to_many :users, Core.Auth.User,
      join_through: Core.Meetings.Attendee,
      unique: true

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = meeting, attrs) do
    meeting
    |> cast(attrs, [:title])
    |> cast_polymorphic_embed(:config, required: true)
    |> validate_required([:title])
    |> validate_length(:title, max: 200)
  end
end
