defmodule CoreWeb.PageController do
  use CoreWeb, :controller

  plug :put_layout, html: {CoreWeb.Layouts, :landing}

  def index(conn, _params) do
    render(conn, :index)
  end

  def privacy(conn, _params) do
    render(conn, :privacy)
  end
end
