defmodule Core.Meetings.Attendee.Config.MonthTest do
  use Core.DataCase

  alias Core.Meetings.Attendee.Config.Month

  describe "changeset/2" do
    test "accepts valid attributes" do
      attrs = %{"available_days" => [0, 1, 30]}

      changeset = Month.changeset(%Month{}, attrs)

      assert changeset.valid?
    end

    test "rejects invalid available_days" do
      attrs = %{"available_days" => [0, 1, 31]}

      changeset = Month.changeset(%Month{}, attrs)

      refute changeset.valid?
    end

    test "sets default values" do
      config = %Month{}
      assert config.available_days == []
    end
  end
end
