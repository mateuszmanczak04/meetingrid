defmodule Core.Meetings.Meeting.Config.DayTest do
  use Core.DataCase

  alias Core.Meetings.Meeting.Config.Day

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Day.changeset(%Day{}, %{})
      assert changeset.valid?
    end

    test "sets default values" do
      _config = %Day{}
    end
  end
end
