defmodule Core.Repo.Migrations.BaseSchemas do
  use Ecto.Migration

  def change do
    create table(:attendees) do
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:meetings) do
      add :title, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:invitations) do
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false
      add :code, :string, null: false
      add :role, :string, default: "user", null: false
    end

    create table(:meetings_attendees) do
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false
      add :attendee_id, references(:attendees, on_delete: :delete_all), null: false
      add :role, :string, default: "user", null: false
      add :available_days, {:array, :integer}
      timestamps(type: :utc_datetime)
    end

    create index(:invitations, [:meeting_id])
    create index(:meetings_attendees, [:meeting_id, :attendee_id], unique: true)
  end
end
