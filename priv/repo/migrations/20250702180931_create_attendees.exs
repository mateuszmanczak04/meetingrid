defmodule Core.Repo.Migrations.CreateAttendees do
  use Ecto.Migration

  def change do
    create table(:attendees) do
      add :name, :string
      add :available_days, {:array, :integer}
      add :event_id, references(:events, on_delete: :delete_all)
      add :browser_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:attendees, [:event_id])
    create index(:attendees, [:browser_id])
  end
end
