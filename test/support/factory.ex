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
      title: "meeting#{System.unique_integer()}"
    }
  end

  def build(:attendee) do
    %Core.Meetings.Attendee{
      available_days: [1, 2],
      role: :user
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
