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

  defstruct [:meeting, :common_days, :attendees]

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

  @spec check_if_already_joined(Meeting.id(), User.t()) ::
          {false, state()} | {Attendee.t(), state()}
  def check_if_already_joined(meeting_id, %User{} = user) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), {:check_if_already_joined, user})
  end

  @spec join_meeting(Meeting.id(), User.t()) :: :ok | :error
  def join_meeting(meeting_id, %User{} = user) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), {:join_meeting, user})
  end

  @spec leave_meeting(Meeting.id(), Attendee.t()) :: :ok | :error
  def leave_meeting(meeting_id, %Attendee{} = current_attendee) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.call(via_tuple(meeting_id), {:leave_meeting, current_attendee})
  end

  @spec toggle_available_day(Meeting.id(), Attendee.t(), Attendee.day()) :: :ok
  def toggle_available_day(meeting_id, %Attendee{} = current_attendee, day_number) do
    {:ok, _pid} = ensure_started(meeting_id)
    GenServer.cast(via_tuple(meeting_id), {:toggle_available_day, current_attendee, day_number})
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

  # Callbacks

  @impl true
  def init(meeting_id) do
    case Meetings.get_meeting(meeting_id) do
      nil -> {:error, :meeting_not_found}
      meeting -> {:ok, reload_state(meeting.id)}
    end
  end

  @impl true
  def handle_call({:check_if_already_joined, user}, _from, state) do
    case Meetings.check_if_already_joined(user, state.meeting) do
      %Attendee{} = current_attendee -> {:reply, {current_attendee, state}, state}
      false -> {:reply, {false, state}, state}
    end
  end

  @impl true
  def handle_call({:join_meeting, current_user}, _from, state) do
    case Meetings.join_meeting(current_user, state.meeting, %{role: :user, available_days: []}) do
      {:ok, _} -> {:reply, :ok, reload_and_broadcast(state.meeting.id)}
      {:error, _} -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:leave_meeting, current_attendee}, from, state) do
    case Meetings.leave_meeting(current_attendee) do
      {:ok, :leave} ->
        {:reply, :ok, reload_and_broadcast(state.meeting.id)}

      {:ok, :terminate} ->
        broadcast(state.meeting.id, :meeting_deleted)
        GenServer.reply(from, :ok)
        {:stop, :shutdown, state}

      {:error, _} ->
        {:reply, :error, state}
    end
  end

  @impl true
  def handle_cast({:toggle_available_day, current_attendee, day_number}, state) do
    case Meetings.toggle_available_day(current_attendee, day_number) do
      {:ok, _} -> {:noreply, reload_and_broadcast(state.meeting.id)}
      {:error, _} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_attendee_role, current_attendee, attendee_to_update, role}, state) do
    case Meetings.update_attendee_role(current_attendee, attendee_to_update, role) do
      {:ok, _} -> {:noreply, reload_and_broadcast(state.meeting.id)}
      {:error, _} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_meeting, current_attendee, attrs}, state) do
    case Meetings.update_meeting(current_attendee, state.meeting, attrs) do
      {:ok, _} -> {:noreply, reload_and_broadcast(state.meeting.id)}
      {:error, _} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:kick_attendee, current_attendee, attendee_to_kick}, state) do
    case Meetings.kick_attendee(current_attendee, attendee_to_kick) do
      {:ok, _} ->
        broadcast_to_attendee(attendee_to_kick.id, :you_were_kicked)
        {:noreply, reload_and_broadcast(state.meeting.id)}

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

  @spec reload_and_broadcast(Meeting.id()) :: state()
  defp reload_and_broadcast(meeting_id) do
    state = reload_state(meeting_id)
    broadcast(meeting_id, {:state_updated, state})
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

  @doc false
  def get_common_days([]) do
    []
  end

  @doc false
  @spec get_common_days([Attendee.t()]) :: [Attendee.day()]
  def get_common_days(attendees) do
    attendees
    |> Enum.map(& &1.available_days)
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
  end

  @doc false
  @spec reload_state(Meeting.id()) :: state()
  def reload_state(meeting_id) do
    meeting = Meetings.get_meeting(meeting_id)

    attendees =
      Meetings.list_meeting_attendees(
        meeting,
        preload: [:user],
        order_by: [:id]
      )

    common_days = get_common_days(attendees)

    %__MODULE__{meeting: meeting, common_days: common_days, attendees: attendees}
  end
end
