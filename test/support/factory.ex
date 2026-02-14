defmodule Core.Factory do
  alias Core.Repo

  # Factories

  def build(:user) do
    %Core.Auth.User{
      name: "user#{System.unique_integer()}"
    }
  end

  def build(:meeting) do
    %Core.Meetings.Meeting{
      title: "meeting#{System.unique_integer()}",
      config: build(:meeting_config_week)
    }
  end

  def build(:meeting_config_week) do
    %Core.Meetings.Meeting.Config.Week{include_weekends: true}
  end

  def build(:meeting_config_day) do
    %Core.Meetings.Meeting.Config.Day{}
  end

  def build(:attendee) do
    %Core.Meetings.Attendee{
      role: :user,
      config: build(:attendee_config_week)
    }
  end

  def build(:attendee_config_week) do
    %Core.Meetings.Attendee.Config.Week{available_days: []}
  end

  def build(:attendee_config_day) do
    %Core.Meetings.Attendee.Config.Day{available_hours: []}
  end

  # Convenience API

  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end

  def insert!(factory_name, attributes \\ []) do
    factory_name |> build(attributes) |> Repo.insert!()
  end
end
