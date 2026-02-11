defmodule Core.Meetings.Meeting.Config.DayTest do
  use Core.DataCase

  alias Core.Meetings.Meeting.Config.Day

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Day.changeset(%Day{}, %{})

      refute changeset.valid?
      assert %{date: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts valid attributes" do
      attrs = %{"date" => ~D[2024-01-15]}

      changeset = Day.changeset(%Day{}, attrs)

      assert changeset.valid?
    end

    test "casts date field correctly" do
      attrs = %{"date" => ~D[2024-01-15]}

      changeset = Day.changeset(%Day{}, attrs)

      assert changeset.changes.date == ~D[2024-01-15]
    end

    test "rejects invalid mode value" do
      attrs = %{"mode" => :invalid, "date" => ~D[2024-01-15]}

      changeset = Day.changeset(%Day{}, attrs)

      refute changeset.valid?
      assert %{mode: ["is invalid"]} = errors_on(changeset)
    end

    test "sets default mode to :day" do
      config = %Day{}
      assert config.mode == :day
    end
  end
end
