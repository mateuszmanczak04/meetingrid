defmodule CoreWeb.PageController do
  use CoreWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/meetings")
  end
end
