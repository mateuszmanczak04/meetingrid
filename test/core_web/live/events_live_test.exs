defmodule CoreWeb.EventsLiveViewTest do
  use CoreWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Core.EventsFixtures
  alias Core.Events

  setup do
    event = event_fixture(%{title: "Evening bar"})
    [event: event]
  end

  test "Two users see their mutual interactions", %{conn: conn, event: event} do
    user_a_name = "John"
    user_b_name = "Matt"

    # User 1 joins and enters name
    {:ok, view_a, _html_a} = live(conn, "/events/#{event.id}")
    form(view_a, "#join_form", %{"name" => "#{user_a_name}"}) |> render_submit()
    assert has_element?(view_a, "tr > td", "#{user_a_name} (You)")

    # User 2 joins and enters name
    {:ok, view_b, _html_a} = live(conn, "/events/#{event.id}")
    form(view_b, "#join_form", %{"name" => user_b_name}) |> render_submit()
    assert has_element?(view_b, "tr > td", "#{user_b_name} (You)")
    assert has_element?(view_b, "tr > td", "#{user_a_name}")
    assert has_element?(view_a, "tr > td", "#{user_b_name}")
    assert has_element?(view_a, "tbody > tr:nth-child(2) > td > button", "Add admin")

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

    # Assert matching day
    assert has_element?(view_a, "thead > tr > th[data-day='2'][data-match='true']")
    assert has_element?(view_b, "thead > tr > th[data-day='2'][data-match='true']")

    # Make User 2 admin
    element(view_a, "tbody > tr:nth-child(2) > td > button", "Add admin") |> render_click()
    assert has_element?(view_a, "tbody > tr:nth-child(2) > td > button", "Remove admin")
    assert has_element?(view_b, "tbody > tr:nth-child(2) > td > button", "Remove admin")

    # Update event's title
    assert has_element?(view_a, "h1", "Evening bar")
    assert has_element?(view_b, "h1", "Evening bar")
    form(view_a, "#update_event_form", %{"title" => "Updated title"}) |> render_submit()
    assert has_element?(view_a, "h1", "Updated title")
    assert has_element?(view_b, "h1", "Updated title")

    # Update User 1 name
    new_user_a_name = "Chris"
    form(view_a, "#attendee_form", %{"name" => "#{new_user_a_name}"}) |> render_submit()
    assert has_element?(view_a, "tr > td", "#{new_user_a_name} (You)")
    assert has_element?(view_b, "tr > td", "#{new_user_a_name}")

    #  User 1 leaves
    {:ok, view_a, _html_a} =
      element(view_a, "#leave_button") |> render_click() |> follow_redirect(conn, ~p"/events")

    # User 2 sets event password
    event_password = "abcdef"
    form(view_b, "#event_password_form", %{"password" => event_password}) |> render_submit()
    assert not has_element?(view_a, "table")
    assert has_element?(view_b, "#flash-info > p", "Successfully updated event password")

    # User 1 re-joins with wrong password
    {:ok, view_a, _html_a} = live(conn, "/events/#{event.id}")

    form(view_a, "#join_form", %{"name" => user_a_name, "password" => "wrong!"})
    |> render_submit()

    assert not has_element?(view_a, "table")
    assert has_element?(view_a, "#flash-error > p", "Wrong password")

    # User 1 re-joins with correct password
    form(view_a, "#join_form", %{"name" => user_a_name, "password" => event_password})
    |> render_submit()

    assert has_element?(view_a, "tr > td", "#{user_a_name} (You)")
    assert has_element?(view_b, "tr > td", "#{user_a_name}")

    # User 2 deletes event
    element(view_b, "#delete-event-button") |> render_click()
    assert Events.get_event(event.id) == nil
  end

  test "Visiting page with non-existing event redirects to /events", %{conn: conn} do
    {:error, {:live_redirect, %{to: redirect_path}}} = live(conn, "/events/123456")
    assert redirect_path == "/events"
  end

  test "Create new event button in /events creates new event and redirects", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/events")

    {:ok, view, _html} =
      element(view, "#create_event_button") |> render_click() |> follow_redirect(conn)

    assert has_element?(view, "#join_form")
    assert has_element?(view, "table")
  end
end
