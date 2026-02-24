defmodule Core.Meetings.MeetingServer do
  @moduledoc """
  You can image `MeetingServer` being just a server that hosts the meeting
  and all LiveView processes that manage user connections are clients connecting
  to it. It should be running only when at least one meeting attendee is
  present online, otherwise should terminate.

  IMPORTANT: Registry key for the meeting_id is integer, not string!
  Remember to do `String.to_integer(meeting_id)` when reading URL params.
  """

  use GenServer, restart: :transient
  alias Core.Meetings
  alias Core.Meetings.Meeting
  alias Core.Meetings.Attendee
  alias Core.Auth.User

  defstruct [:meeting, :attendees, :common_days, :common_hours]

  @type state :: %__MODULE__{}

  @registry_name Core.Meetings.Registry
  @dynamic_supervisor_name Core.Meetings.DynamicSupervisor
  def registry_name, do: @registry_name
  def dynamic_supervisor_name, do: @dynamic_supervisor_name

  # Public API

  @spec start_link(Meeting.id()) :: GenServer.on_start()
  def start_link(meeting_id) do
    GenServer.start_link(__MODULE__, meeting_id, name: via_tuple(meeting_id))
  end

  @spec join_meeting(Meeting.id(), User.t(), binary()) ::
          :ok | :error | {:error, :invalid_code} | {:error, :expired}
  def join_meeting(meeting_id, %User{} = user, code) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), {:join_meeting, user, code})
  end

  @spec leave_meeting(Meeting.id(), Attendee.t()) ::
          :ok | :error | {:error, :last_admin_cant_leave}
  def leave_meeting(meeting_id, %Attendee{} = current_attendee) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), {:leave_meeting, current_attendee})
  end

  @spec get_state(Meeting.id()) :: state()
  def get_state(meeting_id) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), :get_state)
  end

  @spec toggle_available_day(Meeting.id(), Attendee.t(), Attendee.Config.Week.day()) :: :ok
  def toggle_available_day(meeting_id, %Attendee{} = current_attendee, day_number) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:toggle_available_day, current_attendee, day_number})
  end

  @spec toggle_available_hour(Meeting.id(), Attendee.t(), Attendee.Config.Day.hour()) :: :ok
  def toggle_available_hour(meeting_id, %Attendee{} = current_attendee, hour_number) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:toggle_available_hour, current_attendee, hour_number})
  end

  @spec update_attendee_role(Meeting.id(), Attendee.t(), Attendee.t(), Attendee.role()) :: :ok
  def update_attendee_role(
        meeting_id,
        %Attendee{} = current_attendee,
        %Attendee{} = attendee_to_update,
        role
      )
      when role in [:admin, :user] do
    {:ok, _pid} = ensure_started(meeting_id)

    GenServer.cast(
      via_tuple(meeting_id),
      {:update_attendee_role, current_attendee, attendee_to_update, role}
    )
  end

  @spec update_meeting(Meeting.id(), Attendee.t(), map()) :: :ok
  def update_meeting(meeting_id, %Attendee{} = current_attendee, attrs) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:update_meeting, current_attendee, attrs})
  end

  @spec kick_attendee(Meeting.id(), Attendee.t(), Attendee.t()) :: :ok
  def kick_attendee(meeting_id, %Attendee{} = current_attendee, %Attendee{} = attendee_to_kick) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:kick_attendee, current_attendee, attendee_to_kick})
  end

  @spec delete_meeting(Meeting.id(), Attendee.t()) :: :ok
  def delete_meeting(meeting_id, %Attendee{} = current_attendee) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:delete_meeting, current_attendee})
  end

  @spec reload_and_broadcast_if_running(Meeting.id()) :: :ok
  def reload_and_broadcast_if_running(meeting_id) do
    case Registry.lookup(@registry_name, meeting_id) do
      [{_pid, nil}] ->
        GenServer.cast(via_tuple(meeting_id), :reload_and_broadcast)

      [] ->
        :ok
    end
  end

  # Callbacks

  @impl true
  def init(meeting_id) do
    case Meetings.get_meeting(meeting_id) do
      nil -> {:error, :meeting_not_found}
      meeting -> {:ok, reload_state(meeting)}
    end
  end

  @impl true
  def handle_call({:join_meeting, current_user, code}, _from, state) do
    case Meetings.join_meeting(current_user, state.meeting, code) do
      {:ok, _} -> {:reply, :ok, reload_and_broadcast(state.meeting)}
      {:error, :expired} -> {:reply, {:error, :expired}, state}
      {:error, :invalid_code} -> {:reply, {:error, :invalid_code}, state}
      {:error, _} -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:leave_meeting, current_attendee}, _from, state) do
    case Meetings.leave_meeting(current_attendee) do
      {:ok, :leave} ->
        {:reply, :ok, reload_and_broadcast(state.meeting)}

      {:error, :last_admin_cant_leave} ->
        {:reply, {:error, :last_admin_cant_leave}, state}

      {:error, _} ->
        {:reply, :error, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:toggle_available_day, current_attendee, day_number}, state) do
    case Meetings.toggle_available_day(current_attendee, day_number) do
      {:ok, _} -> {:noreply, reload_and_broadcast(state.meeting)}
      {:error, _} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:toggle_available_hour, current_attendee, hour_number}, state) do
    case Meetings.toggle_available_hour(current_attendee, hour_number) do
      {:ok, _} -> {:noreply, reload_and_broadcast(state.meeting)}
      {:error, _} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_attendee_role, current_attendee, attendee_to_update, role}, state) do
    case Meetings.update_attendee_role(current_attendee, attendee_to_update, role) do
      {:ok, _} -> {:noreply, reload_and_broadcast(state.meeting)}
      {:error, _} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_meeting, current_attendee, attrs}, state) do
    case Meetings.update_meeting(current_attendee, state.meeting, attrs) do
      {:ok, _} -> {:noreply, reload_and_broadcast(state.meeting)}
      {:error, _} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:kick_attendee, current_attendee, attendee_to_kick}, state) do
    case Meetings.kick_attendee(current_attendee, attendee_to_kick) do
      {:ok, _} ->
        broadcast_to_attendee(attendee_to_kick.id, :you_were_kicked)
        {:noreply, reload_and_broadcast(state.meeting)}

      {:error, _} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:delete_meeting, current_attendee}, state) do
    case Meetings.delete_meeting(current_attendee, state.meeting) do
      {:ok, _} ->
        broadcast(state.meeting.id, :meeting_deleted)
        {:stop, :shutdown, state}

      {:error, _} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:reload_and_broadcast, state) do
    {:noreply, reload_and_broadcast(state.meeting)}
  end

  # Private utilities

  defp via_tuple(meeting_id) do
    {:via, Registry, {@registry_name, meeting_id}}
  end

  defp ensure_started(meeting_id) do
    case DynamicSupervisor.start_child(
           @dynamic_supervisor_name,
           {__MODULE__, meeting_id}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  @spec reload_and_broadcast(Meeting.t()) :: state()
  defp reload_and_broadcast(meeting) do
    state = reload_state(meeting)
    broadcast(meeting.id, {:state_updated, state})
    state
  end

  defp broadcast(meeting_id, payload) do
    Phoenix.PubSub.broadcast(
      Core.PubSub,
      "meeting:#{meeting_id}",
      payload
    )
  end

  defp broadcast_to_attendee(attendee_id, payload) do
    Phoenix.PubSub.broadcast(
      Core.PubSub,
      "attendee:#{attendee_id}",
      payload
    )
  end

  @spec reload_state(Meeting.t()) :: state()
  defp reload_state(meeting) do
    meeting = Meetings.get_meeting(meeting.id)

    attendees =
      Meetings.list_meeting_attendees(
        meeting,
        preload: [:user],
        order_by: [:id]
      )

    case meeting.config do
      %Meeting.Config.Day{} ->
        common_hours = get_common_hours(attendees)
        %__MODULE__{meeting: meeting, attendees: attendees, common_hours: common_hours}

      %Meeting.Config.Week{} ->
        common_days = get_common_days(attendees)
        %__MODULE__{meeting: meeting, attendees: attendees, common_days: common_days}

      %Meeting.Config.Month{} ->
        common_days = get_common_days(attendees)
        %__MODULE__{meeting: meeting, attendees: attendees, common_days: common_days}
    end
  end

  @spec get_common_days([Attendee.t()]) :: [Attendee.Config.Week.day()]
  defp get_common_days([]), do: []

  defp get_common_days(attendees) do
    attendees
    |> Enum.map(& &1.config.available_days)
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
  end

  @spec get_common_hours([Attendee.t()]) :: [Attendee.Config.Day.hour()]
  defp get_common_hours([]), do: []

  defp get_common_hours(attendees) do
    attendees
    |> Enum.map(& &1.config.available_hours)
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
  end
end
