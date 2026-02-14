defmodule Core.Meetings.Attendee.Config.DayTest do
  use Core.DataCase

  alias Core.Meetings.Attendee.Config.Day

  describe "changeset/2" do
    test "accepts valid attributes" do
      attrs = %{"available_hours" => [0, 1, 23]}

      changeset = Day.changeset(%Day{}, attrs)

      assert changeset.valid?
    end

    test "rejects invalid available_hours" do
      attrs = %{"available_hours" => [0, 1, 24]}

      changeset = Day.changeset(%Day{}, attrs)

      refute changeset.valid?
    end

    test "sets default values" do
      config = %Day{}
      assert config.available_hours == []
    end
  end
end
