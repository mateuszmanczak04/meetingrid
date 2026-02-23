defmodule CoreWeb.Plugs.RequireCurrentUserId do
  @behaviour Plug

  import Plug.Conn
  alias Core.Auth

  @impl true
  def init(opts), do: opts

  @default_user_name "Unknown"

  @impl true
  def call(%Plug.Conn{} = conn, _opts) do
    current_user =
      with user_id when is_integer(user_id) <- get_session(conn, :user_id),
           %Auth.User{} = existing_user <- Core.Auth.get_user(user_id) do
        existing_user
      else
        nil -> Auth.create_user!(%{name: @default_user_name})
      end

    put_session(conn, :user_id, current_user.id)
  end
end
