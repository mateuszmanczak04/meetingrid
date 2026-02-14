defmodule Core.Meetings.Meeting.Config.WeekTest do
  use Core.DataCase

  alias Core.Meetings.Meeting.Config.Week

  describe "changeset/2" do
    test "accepts valid attributes" do
      attrs = %{"include_weekends" => true}

      changeset = Week.changeset(%Week{}, attrs)

      assert changeset.valid?
    end

    test "sets default values" do
      config = %Week{}
      assert config.include_weekends == false
    end
  end
end
