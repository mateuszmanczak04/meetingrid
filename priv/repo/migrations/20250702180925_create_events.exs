defmodule Core.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :title, :string

      timestamps(type: :utc_datetime)
    end
  end
end
