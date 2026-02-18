defmodule Core.Repo.Migrations.AddIndexToInvitationCode do
  use Ecto.Migration

  def change do
    create index(:invitations, [:code])
  end
end
