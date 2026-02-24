defmodule Core.Auth do
  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Auth.User

  @spec get_user(User.id(), keyword()) :: User.t() | nil
  @spec get_user(User.id()) :: User.t() | nil
  def get_user(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    case Repo.get(User, id) do
      nil -> nil
      user -> Repo.preload(user, preload)
    end
  end

  @spec create_user!(map()) :: User.t()
  def create_user!(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert!()
  end

  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @spec change_user(User.t(), map()) :: Ecto.Changeset.t()
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end
end
