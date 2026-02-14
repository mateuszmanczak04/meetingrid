defmodule Core.Meetings.Attendee.Config.WeekTest do
  use Core.DataCase

  alias Core.Meetings.Attendee.Config.Week

  describe "changeset/2" do
    test "accepts valid attributes" do
      attrs = %{"available_days" => [0, 1, 6]}

      changeset = Week.changeset(%Week{}, attrs)

      assert changeset.valid?
    end

    test "rejects invalid available_days" do
      attrs = %{"available_days" => [0, 1, 7]}

      changeset = Week.changeset(%Week{}, attrs)

      refute changeset.valid?
    end

    test "sets default values" do
      config = %Week{}
      assert config.available_days == []
    end
  end
end
