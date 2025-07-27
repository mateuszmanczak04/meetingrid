defmodule Core.Repo.Migrations.AddRoleAttendees do
  use Ecto.Migration

  def change do
    alter table(:attendees) do
      add :role, :string, default: "user", null: false
    end
  end
end
