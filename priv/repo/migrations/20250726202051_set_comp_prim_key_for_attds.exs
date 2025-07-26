defmodule Core.Repo.Migrations.SetCompPrimKeyForAttds do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE attendees DROP CONSTRAINT attendees_pkey"

    alter table(:attendees) do
      remove :id
    end

    execute "ALTER TABLE attendees ALTER COLUMN event_id SET NOT NULL"
    execute "ALTER TABLE attendees ALTER COLUMN browser_id SET NOT NULL"

    execute "ALTER TABLE attendees ADD PRIMARY KEY (event_id, browser_id)"
  end

  def down do
    execute "ALTER TABLE attendees DROP CONSTRAINT attendees_pkey"

    alter table(:attendees) do
      add :id, :bigserial, primary_key: true
    end
  end
end
