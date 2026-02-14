defmodule Core.Meetings.Attendee do
  use Ecto.Schema
  import Ecto.Changeset
  import PolymorphicEmbed

  @type t :: %__MODULE__{}
  @type role :: :user | :admin

  schema "attendees" do
    field :role, Ecto.Enum, values: [:user, :admin]

    polymorphic_embeds_one(:config,
      types: [
        day: Core.Meetings.Attendee.Config.Day,
        week: Core.Meetings.Attendee.Config.Week,
        month: Core.Meetings.Attendee.Config.Month
      ],
      type_field_name: :mode,
      on_type_not_found: :raise,
      on_replace: :update
    )

    belongs_to :meeting, Core.Meetings.Meeting, on_replace: :delete
    belongs_to :user, Core.Auth.User, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = attendee, attrs) do
    attendee
    |> cast(attrs, [:role])
    |> cast_polymorphic_embed(:config, required: true)
    |> validate_required([:role])
  end
end
