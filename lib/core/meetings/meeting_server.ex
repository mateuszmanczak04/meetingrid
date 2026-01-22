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
  alias Core.Repo
  alias Core.Meetings
  alias Core.Auth.User
  alias Core.Meetings.Attendee

  defstruct [:meeting, :common_days, :attendees]

  @registry_name Core.Meetings.Registry
  @dynamic_supervisor_name Core.Meetings.DynamicSupervisor
  def registry_name, do: @registry_name
  def dynamic_supervisor_name, do: @dynamic_supervisor_name

  # Public API

  def start_link(meeting_id) do
    GenServer.start_link(__MODULE__, meeting_id, name: via_tuple(meeting_id))
  end

  def check_if_already_joined(meeting_id, %User{} = user) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), {:check_if_already_joined, user})
  end

  def join_meeting(meeting_id, %User{} = user) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), {:join_meeting, user})
  end

  def update_available_days(meeting_id, %Attendee{} = current_attendee, days)
      when is_list(days) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:update_available_days, current_attendee, days})
  end

  def update_attendee_role(
        meeting_id,
        %Attendee{} = current_attendee,
        %Attendee{} = attendee_to_update,
        role
      )
      when role in [:admin, :user] do
    ensure_started(meeting_id)

    GenServer.cast(
      via_tuple(meeting_id),
      {:update_attendee_role, current_attendee, attendee_to_update, role}
    )
  end

  def update_meeting(meeting_id, %Attendee{} = current_attendee, %{} = attrs) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:update_meeting, current_attendee, attrs})
  end

  def leave_meeting(meeting_id, %Attendee{} = current_attendee) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:leave_meeting, current_attendee})
  end

  def kick_attendee(meeting_id, %Attendee{} = current_attendee, %Attendee{} = attendee_to_kick) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:kick_attendee, current_attendee, attendee_to_kick})
  end

  def delete_meeting(meeting_id, %Attendee{} = current_attendee) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:delete_meeting, current_attendee})
  end

  # Callbacks

  @impl true
  def init(meeting_id) do
    case Meetings.get_meeting(meeting_id) do
      nil ->
        {:error, :meeting_not_found}

      meeting ->
        attendees = Meetings.list_meeting_attendees(meeting, preload: [:user])
        common_days = get_common_days(attendees)

        {:ok, %__MODULE__{meeting: meeting, common_days: common_days, attendees: attendees}}
    end
  end

  @impl true
  def handle_call({:check_if_already_joined, user}, _from, state) do
    case Enum.find(state.attendees, &(&1.user.id == user.id)) do
      nil -> {:reply, {false, state}, state}
      %Attendee{} = current_attendee -> {:reply, {current_attendee, state}, state}
    end
  end

  @impl true
  def handle_call({:join_meeting, user}, _from, state) do
    case Meetings.get_attendee_by(meeting_id: state.meeting.id, user_id: user.id) do
      nil ->
        current_attendee = Meetings.create_attendee!(state.meeting, user)
        new_state = reload_state(state)
        broadcast(new_state.meeting, {:state_updated, new_state})
        {:reply, %{current_attendee: current_attendee, state: new_state}, new_state}

      %Attendee{} = current_attendee ->
        {:reply, %{current_attendee: current_attendee, state: state}, state}
    end
  end

  @impl true
  def handle_cast({:leave_meeting, current_attendee}, state) do
    # TODO: delete entire meeting when all attendees leave
    Meetings.delete_attendee!(current_attendee)
    new_state = reload_state(state)
    broadcast(new_state.meeting, {:state_updated, new_state})
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_available_days, current_attendee, days}, state) do
    Meetings.update_attendee!(current_attendee, %{available_days: days})
    new_state = reload_state(state)
    broadcast(new_state.meeting, {:state_updated, new_state})
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_attendee_role, current_attendee, attendee_to_update, role}, state) do
    if current_attendee.role == :admin do
      Meetings.update_attendee!(attendee_to_update, %{role: role})
      new_state = reload_state(state)
      broadcast(new_state.meeting, {:state_updated, new_state})
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_meeting, current_attendee, attrs}, state) do
    if current_attendee.role == :admin do
      Meetings.update_meeting!(state.meeting, attrs)
      new_state = reload_state(state)
      broadcast(new_state.meeting, {:state_updated, new_state})
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:kick_attendee, current_attendee, attendee_to_kick}, state) do
    if current_attendee.role == :admin do
      Meetings.delete_attendee!(attendee_to_kick)
      new_state = reload_state(state)
      broadcast(new_state.meeting, {:state_updated, new_state})
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:delete_meeting, current_attendee}, state) do
    if current_attendee.role == :admin do
      Meetings.delete_meeting!(state.meeting)
      broadcast(state.meeting, :meeting_deleted)
      {:stop, {:normal, :meeting_deleted}, state}
    else
      {:noreply, state}
    end
  end

  # Private utilities

  defp via_tuple(meeting_id) do
    {:via, Registry, {@registry_name, meeting_id}}
  end

  defp ensure_started(meeting_id) do
    case Registry.lookup(@registry_name, meeting_id) do
      [{pid, _value}] ->
        {:ok, pid}

      [] ->
        DynamicSupervisor.start_child(
          @dynamic_supervisor_name,
          {__MODULE__, meeting_id}
        )
    end
  end

  defp broadcast(meeting, payload) do
    Phoenix.PubSub.broadcast(
      Core.PubSub,
      "meeting:#{meeting.id}",
      payload
    )
  end

  defp get_common_days([]) do
    []
  end

  defp get_common_days(attendees) do
    attendees
    |> Enum.map(& &1.available_days)
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
  end

  defp reload_state(%__MODULE__{meeting: meeting}) do
    meeting = Repo.reload(meeting)
    attendees = Meetings.list_meeting_attendees(meeting, preload: [:user])
    common_days = get_common_days(attendees)
    %__MODULE__{meeting: meeting, common_days: common_days, attendees: attendees}
  end
end
