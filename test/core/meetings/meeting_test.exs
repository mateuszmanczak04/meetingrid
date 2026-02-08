defmodule Core.Meetings.MeetingTest do
  use Core.DataCase, async: true

  alias Core.Meetings.Meeting

  describe "changeset/2" do
    test "valid with required fields" do
      changeset = Meeting.changeset(%Meeting{}, %{title: "Team Standup"})

      assert changeset.valid?
    end

    test "requires title" do
      changeset = Meeting.changeset(%Meeting{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
    end

    test "title must be 200 characters or less" do
      changeset =
        Meeting.changeset(%Meeting{}, %{
          title: String.duplicate("a", 201)
        })

      refute changeset.valid?
      assert "should be at most 200 character(s)" in errors_on(changeset).title
    end

    test "accepts title at max length" do
      changeset =
        Meeting.changeset(%Meeting{}, %{
          title: String.duplicate("a", 200)
        })

      assert changeset.valid?
    end
  end
end
