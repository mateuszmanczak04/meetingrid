defmodule Core.Meetings.Meeting.Config.WeekTest do
  use Core.DataCase

  alias Core.Meetings.Meeting.Config.Week

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Week.changeset(%Week{}, %{})

      refute changeset.valid?
      assert %{include_weekends: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts valid attributes" do
      attrs = %{"include_weekends" => true}

      changeset = Week.changeset(%Week{}, attrs)

      assert changeset.valid?
    end

    test "casts include_weekends field correctly" do
      attrs = %{"include_weekends" => false}

      changeset = Week.changeset(%Week{}, attrs)

      assert changeset.changes.include_weekends == false
    end

    test "rejects invalid mode value" do
      attrs = %{"mode" => "invalid", "include_weekends" => true}

      changeset = Week.changeset(%Week{}, attrs)

      refute changeset.valid?
      assert %{mode: ["is invalid"]} = errors_on(changeset)
    end

    test "sets default mode to :week" do
      config = %Week{}
      assert config.mode == :week
    end
  end
end
