defmodule Core.Meetings.Meeting.Config.MonthTest do
  use Core.DataCase

  alias Core.Meetings.Meeting.Config.Month

  describe "changeset/2" do
    test "accepts valid attributes" do
      for days_amount <- [28, 30, 31] do
        attrs = %{"days_amount" => days_amount}

        changeset = Month.changeset(%Month{}, attrs)

        assert changeset.valid?
        assert changeset.changes.days_amount == days_amount
      end
    end

    test "rejects invalid attributes" do
      attrs = %{"days_amount" => 29}

      changeset = Month.changeset(%Month{}, attrs)

      refute changeset.valid?
    end

    test "sets default values" do
      _config = %Month{}
    end
  end
end
