defmodule Core.Meetings.MeetingServer do
  @moduledoc """
  You can image `MeetingServer` being just a server that hosts the meeting
  and all LiveView processes that manage user connections are clients connecting
  to it. It should be running only when at least one meeting attendee is
  present online, otherwise should terminate.
  """

  use GenServer
  alias Core.Repo
  alias Core.Meetings
  alias Core.Auth.User
  alias Core.Meetings.Attendee

  defstruct [:meeting, :common_days, :attendees]

  @doc """
  Call as a newly-joined attendee to immediately get the full state and
  inform the rest of people about joining.
  """
  def join_meeting(meeting_id, %User{} = user) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), {:join_meeting, user})
  end

  @doc """
  Call when updates available days. Database concerns are resolved inside of this.
  """
  def update_available_days(meeting_id, %Attendee{} = current_attendee, [_ | _] = days) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:update_available_days, current_attendee, days})
  end

  @doc """
  Call only as an admin to update role of other attendees.
  """
  def update_role(
        meeting_id,
        %Attendee{} = current_attendee,
        %Attendee{} = attendee_to_update,
        role
      ) do
    ensure_started(meeting_id)

    GenServer.cast(
      via_tuple(meeting_id),
      {:update_role, current_attendee, attendee_to_update, role}
    )
  end

  @doc """
  E.g. update meeting's title.
  """
  def update_meeting(meeting_id, %Attendee{} = current_attendee, %{} = attrs) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:update_meeting, current_attendee, attrs})
  end

  @doc """
  Call after user presses "Leave" button.
  It's all about DB belonging and not being currently online.
  """
  def leave_meeting(meeting_id, %Attendee{} = current_attendee) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:leave_meeting, current_attendee})
  end

  @doc """
  Call it only as an admin to kick some other attendee.
  """
  def kick_attendee(meeting_id, %Attendee{} = current_attendee, %Attendee{} = attendee_to_kick) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:kick_attendee, current_attendee, attendee_to_kick})
  end

  @doc """
  Call after meeting admin presses "Delete meeting" button.
  """
  def delete_meeting(meeting_id) do
    ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), :delete_meeting)
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
        attendees = meeting.attendees
        common_days = get_common_days(attendees)
        {:ok, %__MODULE__{meeting: meeting, common_days: common_days, attendees: attendees}}
    end
  end

  @impl true
  def handle_call({:join_meeting, user}, _from, %{meeting: meeting} = state) do
    attendee =
      case Meetings.get_attendee_by(meeting_id: meeting.id, user_id: user.id) do
        nil -> Meetings.create_attendee!(meeting, user)
        %Attendee{} = attendee -> attendee
      end

    new_state = reload_state(state)

    broadcast(meeting, {:state_updated, new_state})
    {:reply, %{current_attendee: attendee, state: new_state}, new_state}
  end

  @impl true
  def handle_cast({:leave_meeting, current_attendee}, state) do
    # TODO: delete entire meeting when all attendees leave
    Meetings.delete_attendee!(current_attendee)
    new_state = reload_state(state)
    broadcast(state.meeting, {:state_updated, new_state})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_available_days, current_attendee, days}, state) do
    Meetings.update_attendee!(current_attendee, %{available_days: days})
    new_state = reload_state(state)
    broadcast(state.meeting, {:state_updated, new_state})
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_role, _current_attendee, attendee_to_update, role}, state) do
    # TODO: check permission
    Meetings.update_attendee!(attendee_to_update, %{role: role})
    new_state = reload_state(state)
    broadcast(state.meeting, {:state_updated, new_state})
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_meeting, _current_attendee, attrs}, state) do
    # TODO: check permission
    Meetings.update_meeting!(state.meeting, attrs)
    new_state = reload_state(state)
    broadcast(state.meeting, {:state_updated, new_state})
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:kick_attendee, _current_attendee, attendee_to_kick}, state) do
    # TODO: check permission
    Meetings.delete_attendee!(attendee_to_kick)
    new_state = reload_state(state)
    broadcast(state.meeting, {:state_updated, new_state})
    {:noreply, state}
  end

  @impl true
  def handle_cast(:delete_meeting, %{meeting: meeting} = state) do
    Meetings.delete_meeting!(meeting)
    broadcast(meeting, :meeting_deleted)
    # TODO: stop when no people online too, not only when deleting meeting permantently
    {:stop, {:shutdown, :meeting_deleted}, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  # Private utilities

  defp via_tuple(meeting_id) do
    {:via, Registry, {Meetings.Registry, meeting_id}}
  end

  defp ensure_started(meeting_id) do
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
    meeting =
      meeting
      |> Repo.reload()
      |> Repo.preload(attendees: :user)

    attendees = meeting.attendees
    common_days = get_common_days(attendees)

    %__MODULE__{meeting: meeting, common_days: common_days, attendees: attendees}
  end
end
