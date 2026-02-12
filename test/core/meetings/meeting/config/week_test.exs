defmodule Core.Meetings.Meeting.Config.WeekTest do
  use Core.DataCase

  alias Core.Meetings.Meeting.Config.Week

  describe "changeset/2" do
    test "accepts valid attributes" do
      attrs = %{"include_weekends" => true}

      changeset = Week.changeset(%Week{}, attrs)

      assert changeset.valid?
    end

    test "rejects invalid mode value" do
      attrs = %{"mode" => "invalid", "include_weekends" => true}

      changeset = Week.changeset(%Week{}, attrs)

      refute changeset.valid?
      assert %{mode: ["is invalid"]} = errors_on(changeset)
    end

    test "sets default values" do
      config = %Week{}
      assert config.mode == :week
      assert config.include_weekends == false
    end
  end
end
