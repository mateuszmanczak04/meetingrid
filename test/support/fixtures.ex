defmodule Core.Fixtures do
  # alias Core.Auth.User
  # alias Core.Meetings
  # alias Core.Meetings.Meeting

  # def user_fixture(attrs \\ %{}) do
  #   attrs = Map.put_new(attrs, :name, "User name")
  #   Core.Auth.create_user!(attrs)
  # end

  # def meeting_fixture(%User{} = user, attrs \\ %{}) do
  #   attrs = Map.put_new(attrs, :title, "Meeting title")
  #   {:ok, meeting} = Meetings.create_meeting(user, attrs)
  #   meeting
  # end

  # def attendee_fixture(%Meeting{} = meeting, %User{} = user, attrs \\ %{}) do
  #   attrs =
  #     attrs
  #     |> Map.put_new(:role, :user)
  #     |> Map.put_new(:available_days, [])

  #   Meetings.create_attendee!(meeting, user, attrs)
  # end
end
