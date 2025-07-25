defmodule CoreWeb.EventsLiveViewTest do
  use CoreWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Core.EventsFixtures

  setup do
    event = event_fixture()
    [event: event]
  end

  test "Two users see their mutual interactions", %{conn: conn, event: event} do
    # User 1 joins and enters name
    {:ok, view_a, _html_a} = live(conn, "/events?event_id=#{event.id}")
    form(view_a, "#join_form", %{"name" => "John"}) |> render_submit()
    assert has_element?(view_a, "tr > td", "You (John)")

    # User 2 joins and enters name
    {:ok, view_b, _html_a} = live(conn, "/events?event_id=#{event.id}")
    form(view_b, "#join_form", %{"name" => "Matt"}) |> render_submit()
    assert has_element?(view_b, "tr > td", "You (Matt)")
    assert has_element?(view_b, "tr > td", "John")
    assert has_element?(view_a, "tr > td", "Matt")

    # User 1 chooses days
    element(view_a, "tbody > tr:first-child > td[data-day='1']") |> render_click()
    element(view_a, "tbody > tr:first-child > td[data-day='2']") |> render_click()
    element(view_a, "tbody > tr:first-child > td[data-day='6']") |> render_click()

    # User 2 chooses days
    element(view_b, "tbody > tr:first-child > td[data-day='0']") |> render_click()
    element(view_b, "tbody > tr:first-child > td[data-day='2']") |> render_click()
    element(view_b, "tbody > tr:first-child > td[data-day='4']") |> render_click()

    assert has_element?(
             view_a,
             "tbody > tr:nth-child(2) > td[data-day='0'][data-selected='true']"
           )

    assert has_element?(
             view_a,
             "tbody > tr:nth-child(2) > td[data-day='2'][data-selected='true']"
           )

    assert has_element?(
             view_a,
             "tbody > tr:nth-child(2) > td[data-day='4'][data-selected='true']"
           )

    assert has_element?(
             view_b,
             "tbody > tr:nth-child(2) > td[data-day='1'][data-selected='true']"
           )

    assert has_element?(
             view_b,
             "tbody > tr:nth-child(2) > td[data-day='2'][data-selected='true']"
           )

    assert has_element?(
             view_b,
             "tbody > tr:nth-child(2) > td[data-day='6'][data-selected='true']"
           )
  end
end
