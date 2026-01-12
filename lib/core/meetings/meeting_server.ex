defmodule Core.Meetings.MeetingServer do
  use GenServer
  alias Core.Meetings

  defmodule State do
    @moduledoc """
    State of the current meeting. It's shared between all attendees.
    """

    @enforce_keys [:meeting, :common_days]
    defstruct [:meeting, :common_days]
  end

  def ensure_started(meeting_id) do
    case Registry.lookup(Meetings.Registry, meeting_id) do
      [{pid, _value}] ->
        {:ok, pid}

      [] ->
        DynamicSupervisor.start_child(
          Meetings.DynamicSupervisor,
          {__MODULE__, meeting_id}
        )
    end
  end

  def start_link(meeting_id) do
    GenServer.start_link(__MODULE__, meeting_id, name: via_tuple(meeting_id))
  end

  @impl true
  def init(meeting_id) do
    case Meetings.get_meeting(meeting_id, preload: [attendees: :user]) do
      nil ->
        {:error, :meeting_not_found}

      meeting ->
        common_days = get_common_days(meeting.attendees)
        {:ok, %State{meeting: meeting, common_days: common_days}}
    end
  end

  @impl true
  def handle_call(:get_state, _from, %{meeting: _, common_days: _} = state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:refresh, %State{meeting: meeting} = _state) do
    meeting =
      meeting
      |> Core.Repo.reload()
      |> Core.Repo.preload([attendees: :user], force: true)

    common_days = get_common_days(meeting.attendees)

    new_state = %State{meeting: meeting, common_days: common_days}

    broadcast(meeting, {:state_updated, new_state})

    {:noreply, new_state}
  end

  def handle_cast(:delete_meeting, %{meeting: meeting} = state) do
    Meetings.delete_meeting!(meeting)
    broadcast(meeting, :meeting_deleted)
    # TODO: terminate
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  def get_state(meeting_id) do
    ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), :get_state)
  end

  def refresh(meeting_id) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), :refresh)
  end

  def delete_meeting(meeting_id) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), :delete_meeting)
  end

  defp via_tuple(meeting_id) do
    {:via, Registry, {Meetings.Registry, meeting_id}}
  end

  defp broadcast(meeting, payload) do
    Phoenix.PubSub.broadcast(
      Core.PubSub,
      "meeting:#{meeting.id}",
      payload
    )
  end

  defp get_common_days(attendees) do
    attendees
    |> Enum.map(& &1.available_days)
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
  end
end
