defmodule Core.Repo.Migrations.AddConfigToAttendee do
  use Ecto.Migration

  def change do
    alter table("attendees") do
      add :config, :map, null: false
      remove :available_days
    end
  end
end
