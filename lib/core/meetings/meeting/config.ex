defmodule Core.Meetings.Meeting.Config do
  use Ecto.Type

  alias Core.Meetings.Meeting.Config.Day
  alias Core.Meetings.Meeting.Config.Week

  @impl Ecto.Type
  def type(), do: :map

  @impl Ecto.Type
  def cast(%Day{} = config), do: {:ok, config}
  def cast(%Week{} = config), do: {:ok, config}

  def cast(data) when is_map(data) do
    mode = data["mode"] || data[:mode]

    changeset =
      case mode do
        "day" -> Day.changeset(%Day{}, data)
        :day -> Day.changeset(%Day{}, data)
        "week" -> Week.changeset(%Week{}, data)
        :week -> Week.changeset(%Week{}, data)
        _ -> nil
      end

    if changeset && changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      :error
    end
  end

  def cast(_data), do: :error

  @impl Ecto.Type
  def load(%{"mode" => "day"} = data), do: {:ok, Ecto.embedded_load(Day, data, :json)}
  def load(%{"mode" => "week"} = data), do: {:ok, Ecto.embedded_load(Week, data, :json)}
  def load(_), do: :error

  @impl Ecto.Type
  def dump(%Day{} = config), do: {:ok, Ecto.embedded_dump(config, :json)}
  def dump(%Week{} = config), do: {:ok, Ecto.embedded_dump(config, :json)}
  def dump(_), do: :error
end
