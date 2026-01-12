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
        %Auth.User{} = existing -> Core.Repo.reload(existing)
        _ -> Auth.create_user!(%{name: "Unknown"})
      end

    put_session(conn, :user, user)
  end
end
