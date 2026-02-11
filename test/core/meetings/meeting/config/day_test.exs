defmodule Core.Meetings.Meeting.Config.DayTest do
  use Core.DataCase

  alias Core.Meetings.Meeting.Config.Day

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Day.changeset(%Day{}, %{})
      assert changeset.valid?
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
