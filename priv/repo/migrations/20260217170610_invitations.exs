defmodule Core.Repo.Migrations.Invitations do
  use Ecto.Migration

  def change do
    alter table(:invitations) do
      remove :role
      add :expires_at, :utc_datetime
    end
  end
end
