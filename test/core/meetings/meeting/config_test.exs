defmodule Core.Meetings.Meeting.ConfigTest do
  use ExUnit.Case, async: true

  alias Core.Meetings.Meeting.Config

  describe "cast/1" do
    test "casts struct successfully" do
      day_config = %Config.Day{mode: :day, date: ~D[2024-01-01]}
      assert {:ok, ^day_config} = Config.cast(day_config)
    end

    test "casts map with string mode" do
      data = %{"mode" => "day", "date" => ~D[2024-01-01]}
      assert {:ok, %Config.Day{mode: :day}} = Config.cast(data)
    end

    test "casts map with atom mode" do
      data = %{"mode" => "day", "date" => "2024-01-01"}
      assert {:ok, %Config.Day{mode: :day}} = Config.cast(data)
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
      data = %{"mode" => "day", "date" => "invalid"}
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
      data = %{"mode" => "day", "date" => ~D[2024-01-01]}
      assert {:ok, %Config.Day{mode: :day, date: ~D[2024-01-01]}} = Config.load(data)
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
      day_config = %Config.Day{mode: :day, date: ~D[2024-01-01]}
      assert {:ok, map} = Config.dump(day_config)
      assert is_map(map)
      assert map.mode == :day
    end

    test "returns error for invalid data" do
      assert :error = Config.dump(%{})
      assert :error = Config.dump("string")
      assert :error = Config.dump(nil)
    end
  end
end
