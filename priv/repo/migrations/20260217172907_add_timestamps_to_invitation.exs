defmodule Core.Repo.Migrations.AddTimestampsToInvitation do
  use Ecto.Migration

  def change do
    alter table(:invitations) do
      timestamps(type: :utc_datetime)
    end
  end
end
