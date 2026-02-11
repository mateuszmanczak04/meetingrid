defmodule Core.Meetings.Meeting.ConfigTest do
  use ExUnit.Case, async: true

  alias Core.Meetings.Meeting.Config

  describe "cast/1" do
    test "casts struct successfully" do
      week_config = %Config.Week{mode: :week, include_weekends: true}
      assert {:ok, ^week_config} = Config.cast(week_config)
    end

    test "casts map with string mode" do
      data = %{"mode" => "week", "include_weekends" => true}
      assert {:ok, %Config.Week{mode: :week}} = Config.cast(data)
    end

    test "casts map with atom mode" do
      data = %{"mode" => "week", "include_weekends" => true}
      assert {:ok, %Config.Week{mode: :week}} = Config.cast(data)
    end

    test "returns error for invalid mode" do
      data = %{"mode" => "invalid"}
      assert :error = Config.cast(data)
    end

    test "returns error for map without mode" do
      data = %{"other" => "value"}
      assert :error = Config.cast(data)
    end

    test "returns error for invalid changeset" do
      data = %{"mode" => "week", "include_weekends" => "invalid"}
      assert :error = Config.cast(data)
    end

    test "returns error for non-map data" do
      assert :error = Config.cast("string")
      assert :error = Config.cast(123)
      assert :error = Config.cast(nil)
      assert :error = Config.cast([])
    end
  end

  describe "load/1" do
    test "loads config from database map" do
      data = %{"mode" => "week", "include_weekends" => true}
      assert {:ok, %Config.Week{mode: :week, include_weekends: true}} = Config.load(data)
    end

    test "returns error for invalid mode" do
      data = %{"mode" => "invalid"}
      assert :error = Config.load(data)
    end

    test "returns error for missing mode" do
      data = %{"other" => "value"}
      assert :error = Config.load(data)
    end
  end

  describe "dump/1" do
    test "dumps struct to map" do
      week_config = %Config.Week{mode: :week, include_weekends: true}
      assert {:ok, map} = Config.dump(week_config)
      assert is_map(map)
      assert map.mode == :week
    end

    test "returns error for invalid data" do
      assert :error = Config.dump(%{})
      assert :error = Config.dump("string")
      assert :error = Config.dump(nil)
    end
  end
end
