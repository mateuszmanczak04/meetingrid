defmodule Core.Auth do
  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Auth.User

  @type id :: pos_integer()

  @spec get_user(id(), keyword()) :: User.t() | nil
  @spec get_user(id()) :: User.t() | nil
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
    |> User.create_changeset(attrs)
    |> Repo.insert!()
  end

  @spec update_user!(User.t(), map()) :: User.t()
  def update_user!(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update!()
  end

  @spec delete_user!(User.t()) :: User.t()
  def delete_user!(%User{} = user) do
    Repo.delete!(user)
  end
end
