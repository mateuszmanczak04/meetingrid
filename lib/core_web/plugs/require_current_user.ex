defmodule CoreWeb.Plugs.RequireCurrentUser do
  @behaviour Plug

  import Plug.Conn
  alias Core.Auth

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{} = conn, _opts) do
    user =
      conn
      |> get_session(:user)
      |> case do
        nil -> Auth.create_user!(%{name: "Unknown"})
        existing -> Core.Repo.reload(existing)
      end

    put_session(conn, :user, user)
  end
end
