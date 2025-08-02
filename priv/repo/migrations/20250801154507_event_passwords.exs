defmodule Core.Repo.Migrations.EventPasswords do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :password, :string, null: true
    end
  end
end
