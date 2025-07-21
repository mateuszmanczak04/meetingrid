defmodule CoreWeb.Plugs.RequireBrowserId do
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{} = conn, _opts) do
    if get_session(conn, :browser_id) do
      conn
    else
      put_session(conn, :browser_id, Ecto.UUID.generate())
    end
  end
end
