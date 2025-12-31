defmodule Core.Auth do
  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Auth.User

  def get_user(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    User
    |> Repo.get(id)
    |> Repo.preload(preload)
  end

  def create_user!(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert!()
  end

  def update_user!(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update!()
  end

  def delete_user!(%User{} = user) do
    Repo.delete!(user)
  end
end
