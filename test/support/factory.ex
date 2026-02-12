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
      config: %Core.Meetings.Meeting.Config.Week{mode: :week, include_weekends: true}
    }
  end

  def build(:attendee) do
    %Core.Meetings.Attendee{
      role: :user,
      config: %Core.Meetings.Attendee.Config.Week{
        mode: :week,
        available_days: []
      }
    }
  end

  # Convenience API

  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end

  def insert!(factory_name, attributes \\ []) do
    factory_name |> build(attributes) |> Repo.insert!()
  end
end
