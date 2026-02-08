defmodule Core.Meetings do
  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Auth

  alias Core.Meetings.Meeting
  alias Core.Meetings.Attendee

  @spec get_meeting(Meeting.id(), keyword()) :: Meeting.t() | nil
  def get_meeting(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    case Repo.get(Meeting, id) do
      nil -> nil
      meeting -> Repo.preload(meeting, preload)
    end
  end

  @spec create_meeting(Auth.User.t(), map()) :: {:ok, Attendee.t()} | {:error, Ecto.Changeset.t()}
  def create_meeting(%Auth.User{} = current_user, attrs) do
    Repo.transact(fn ->
      with {:ok, meeting} <-
             %Meeting{}
             |> Meeting.changeset(attrs)
             |> Repo.insert(),
           {:ok, attendee} <-
             %Attendee{}
             |> Attendee.changeset(%{role: :admin, available_days: []})
             |> Ecto.Changeset.put_assoc(:meeting, meeting)
             |> Ecto.Changeset.put_assoc(:user, current_user)
             |> Repo.insert() do
        attendee = Repo.preload(attendee, :meeting)
        {:ok, attendee}
      end
    end)
  end

  @spec update_meeting(Attendee.t(), Meeting.t(), map()) ::
          {:ok, Meeting.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def update_meeting(%Attendee{} = current_attendee, %Meeting{} = meeting, attrs) do
    with :ok <- ensure_is_admin(current_attendee) do
      meeting
      |> Meeting.changeset(attrs)
      |> Repo.update()
    end
  end

  @spec delete_meeting(Attendee.t(), Meeting.t()) ::
          {:ok, Meeting.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def delete_meeting(%Attendee{} = current_attendee, %Meeting{} = meeting) do
    with :ok <- ensure_is_admin(current_attendee) do
      Repo.delete(meeting)
    end
  end

  @spec list_meeting_attendees(Meeting.t(), keyword()) :: [Attendee.t()]
  @spec list_meeting_attendees(Meeting.t()) :: [Attendee.t()]
  def list_meeting_attendees(%Meeting{} = meeting, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])
    order_by = Keyword.get(opts, :order_by, [])

    meeting
    |> Ecto.assoc(:attendees)
    |> order_by(^order_by)
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @spec get_attendee_by(keyword(), keyword()) :: Attendee.t() | nil
  @spec get_attendee_by(keyword()) :: Attendee.t() | nil
  def get_attendee_by(clauses, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    case Repo.get_by(Attendee, clauses) do
      nil -> nil
      attendee -> Repo.preload(attendee, preload)
    end
  end

  @spec check_if_already_joined(Auth.User.t(), Meeting.t()) :: Attendee.t() | false
  def check_if_already_joined(%Auth.User{} = user, %Meeting{} = meeting) do
    case get_attendee_by(user_id: user.id, meeting_id: meeting.id) do
      nil -> false
      %Attendee{} = current_attendee -> current_attendee
    end
  end

  @spec join_meeting(Auth.User.t(), Meeting.t(), map()) ::
          {:ok, Attendee.t()} | {:error, Ecto.Changeset.t()}
  def join_meeting(%Auth.User{} = current_user, %Meeting{} = meeting, attrs) do
    %Attendee{}
    |> Attendee.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:meeting, meeting)
    |> Ecto.Changeset.put_assoc(:user, current_user)
    |> Repo.insert()
  end

  @spec update_attendee_role(Attendee.t(), Attendee.t(), Attendee.role()) ::
          {:ok, Attendee.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def update_attendee_role(
        %Attendee{} = current_attendee,
        %Attendee{} = attendee_to_update,
        role
      ) do
    with :ok <- ensure_is_admin(current_attendee) do
      attendee_to_update
      |> Attendee.changeset(%{role: role})
      |> Repo.update()
    end
  end

  @spec toggle_available_day(Attendee.t(), Attendee.day()) ::
          {:ok, Attendee.t()} | {:error, Ecto.Changeset.t()}
  def toggle_available_day(%Attendee{} = current_attendee, day_number) do
    available_days =
      if day_number in current_attendee.available_days do
        current_attendee.available_days -- [day_number]
      else
        [day_number | current_attendee.available_days]
      end

    current_attendee
    |> Attendee.changeset(%{available_days: available_days})
    |> Repo.update()
  end

  @spec leave_meeting(Attendee.t()) ::
          {:ok, :leave} | {:ok, :terminate} | {:error, Ecto.Changeset.t()}
  def leave_meeting(%Attendee{} = current_attendee) do
    Repo.transact(fn ->
      meeting = get_meeting(current_attendee.meeting_id, preload: :attendees)

      if length(meeting.attendees) == 1 do
        Repo.delete(meeting)
        {:ok, :terminate}
      else
        Repo.delete(current_attendee)
        {:ok, :leave}
      end
    end)
  end

  @spec kick_attendee(Attendee.t(), Attendee.t()) ::
          {:ok, Attendee.t()} | {:error, Ecto.Changeset.t() | :unauthorized | :unallowed_on_self}
  def kick_attendee(%Attendee{} = current_attendee, %Attendee{} = attendee_to_kick) do
    with :ok <- ensure_is_admin(current_attendee),
         :ok <- ensure_is_not_self(current_attendee, attendee_to_kick) do
      Repo.delete(attendee_to_kick)
    end
  end

  defp ensure_is_admin(%Attendee{role: :admin}), do: :ok
  defp ensure_is_admin(%Attendee{} = _attendee), do: {:error, :unauthorized}

  defp ensure_is_not_self(%Attendee{} = current, %Attendee{} = other) when current == other,
    do: {:error, :unallowed_on_self}

  defp ensure_is_not_self(%Attendee{}, %Attendee{}),
    do: :ok
end
