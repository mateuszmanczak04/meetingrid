defmodule Core.Meetings.AttendeeTest do
  use Core.DataCase, async: true

  alias Core.Meetings.Attendee

  describe "changeset/2" do
    test "valid with all required fields" do
      changeset =
        Attendee.changeset(%Attendee{}, %{
          role: :user,
          available_days: [1, 3, 5]
        })

      assert changeset.valid?
    end

    test "valid with empty available_days" do
      changeset =
        Attendee.changeset(%Attendee{}, %{
          role: :admin,
          available_days: []
        })

      assert changeset.valid?
    end

    test "requires role" do
      changeset = Attendee.changeset(%Attendee{}, %{available_days: [1]})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end

    test "requires available_days" do
      changeset = Attendee.changeset(%Attendee{}, %{role: :user})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).available_days
    end

    test "rejects invalid role" do
      changeset =
        Attendee.changeset(%Attendee{}, %{
          role: :moderator,
          available_days: [1]
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "rejects days outside valid range" do
      changeset =
        Attendee.changeset(%Attendee{}, %{
          role: :user,
          available_days: [1, 7]
        })

      refute changeset.valid?
      assert "must be between 0 and 6" in errors_on(changeset).available_days
    end

    test "accepts all valid days" do
      changeset =
        Attendee.changeset(%Attendee{}, %{
          role: :user,
          available_days: [0, 1, 2, 3, 4, 5, 6]
        })

      assert changeset.valid?
    end

    # Test the bug fix - update without changing available_days
    test "valid when updating only role" do
      attendee = %Attendee{available_days: [1, 2], role: :user}

      changeset = Attendee.changeset(attendee, %{role: :admin})

      assert changeset.valid?
      assert changeset.changes == %{role: :admin}
    end
  end
end
