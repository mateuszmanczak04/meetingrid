defmodule Core.Repo.Migrations.AddConfigToMeetings do
  use Ecto.Migration

  def change do
    alter table("meetings") do
      add :config, :map, null: false
    end
  end
end
