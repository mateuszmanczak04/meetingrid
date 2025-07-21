defmodule CoreWeb.PageControllerTest do
  use CoreWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn, 302) =~ "/events"
  end
end
