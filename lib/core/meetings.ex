defmodule Core.Meetings do
  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Auth

  alias Core.Meetings.Meeting
  alias Core.Meetings.Attendee
  alias Core.Meetings.Invitation

  @spec list_user_meetings(Auth.User.t()) :: [Meeting.t()]
  def list_user_meetings(%Auth.User{} = user) do
    user
    |> Ecto.assoc(:meetings)
    |> order_by([:inserted_at])
    |> Repo.all()
  end

  @spec list_user_attendees(Auth.User.t()) :: [Attendee.t()]
  def list_user_attendees(%Auth.User{} = user, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    user
    |> Ecto.assoc(:attendees)
    |> order_by([:inserted_at])
    |> Repo.all()
    |> Repo.preload(preload)
  end

  @spec get_meeting(Meeting.id(), keyword()) :: Meeting.t() | nil
  def get_meeting(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    case Repo.get(Meeting, id) do
      nil -> nil
      meeting -> Repo.preload(meeting, preload)
    end
  end

  @spec change_meeting(Meeting.t(), map()) :: Ecto.Changeset.t()
  def change_meeting(%Meeting{} = meeting, %{} = attrs \\ %{}) do
    Meeting.changeset(meeting, attrs)
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
             |> Attendee.changeset(%{
               role: :admin,
               config: %{
                 mode:
                   case meeting.config do
                     %Meeting.Config.Week{} -> :week
                     %Meeting.Config.Day{} -> :day
                     %Meeting.Config.Month{} -> :month
                   end
               }
             })
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

  @spec join_meeting(Auth.User.t(), Meeting.t(), binary()) ::
          {:ok, Attendee.t()} | {:error, Ecto.Changeset.t() | :invalid_code | :expired}
  def join_meeting(%Auth.User{} = current_user, %Meeting{} = meeting, code) do
    case Repo.get_by(Invitation, meeting_id: meeting.id, code: code) do
      nil ->
        {:error, :invalid_code}

      invitation ->
        case DateTime.compare(DateTime.utc_now(), invitation.expires_at) do
          :gt ->
            {:error, :expired}

          _ ->
            %Attendee{}
            |> Attendee.changeset(%{
              role: :user,
              config: %{
                mode:
                  case meeting.config do
                    %Meeting.Config.Week{} -> :week
                    %Meeting.Config.Day{} -> :day
                    %Meeting.Config.Month{} -> :month
                  end
              }
            })
            |> Ecto.Changeset.put_assoc(:meeting, meeting)
            |> Ecto.Changeset.put_assoc(:user, current_user)
            |> Repo.insert()
        end
    end
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

  @spec toggle_available_day(Attendee.t(), Attendee.Config.Week.day()) ::
          {:ok, Attendee.t()} | {:error, Ecto.Changeset.t()}
  def toggle_available_day(%Attendee{} = current_attendee, day_number)
      when is_struct(current_attendee.config, Attendee.Config.Week) or
             is_struct(current_attendee.config, Attendee.Config.Month) do
    available_days =
      if day_number in current_attendee.config.available_days do
        current_attendee.config.available_days -- [day_number]
      else
        [day_number | current_attendee.config.available_days]
      end

    current_attendee
    |> Attendee.changeset(%{config: %{available_days: available_days}})
    |> Repo.update()
  end

  @spec toggle_available_hour(Attendee.t(), Attendee.Config.Day.hour()) ::
          {:ok, Attendee.t()} | {:error, Ecto.Changeset.t()}
  def toggle_available_hour(%Attendee{} = current_attendee, hour_number)
      when is_struct(current_attendee.config, Attendee.Config.Day) do
    available_hours =
      if hour_number in current_attendee.config.available_hours do
        current_attendee.config.available_hours -- [hour_number]
      else
        [hour_number | current_attendee.config.available_hours]
      end

    current_attendee
    |> Attendee.changeset(%{config: %{available_hours: available_hours}})
    |> Repo.update()
  end

  @spec leave_meeting(Attendee.t()) ::
          {:ok, :leave}
          | {:error, :last_admin_cant_leave}
          | {:error, Ecto.Changeset.t()}
  def leave_meeting(%Attendee{} = current_attendee) do
    Repo.transact(fn ->
      meeting = get_meeting(current_attendee.meeting_id, preload: :attendees)

      case current_attendee.role do
        :admin ->
          how_many_admins = Enum.count(meeting.attendees, &(&1.role == :admin))

          if how_many_admins == 1 do
            {:error, :last_admin_cant_leave}
          else
            Repo.delete(current_attendee)
            {:ok, :leave}
          end

        :user ->
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

  @spec create_invitation(Attendee.t(), %{duration: binary()}) ::
          {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()} | {:error, :unauthorized}
  def create_invitation(%Attendee{} = current_attendee, %{duration: duration}) do
    with :ok <- ensure_is_admin(current_attendee) do
      expires_at = DateTime.utc_now()

      expires_at =
        case duration do
          "hour" -> DateTime.add(expires_at, 1, :hour)
          "day" -> DateTime.add(expires_at, 1, :day)
          "week" -> DateTime.add(expires_at, 7, :day)
          "month" -> DateTime.add(expires_at, 30, :day)
          "year" -> DateTime.add(expires_at, 365, :day)
          _ -> raise "Unknown duration of invitation"
        end

      code = Enum.random(100_000..999_999) |> to_string()

      meeting = get_meeting(current_attendee.meeting_id)

      %Invitation{}
      |> Invitation.changeset(%{"expires_at" => expires_at, "code" => code})
      |> Ecto.Changeset.put_assoc(:meeting, meeting)
      |> Repo.insert()
    end
  end

  @spec list_meeting_invitations(Meeting.t()) :: [Invitation.t()]
  def list_meeting_invitations(%Meeting{} = meeting) do
    Ecto.assoc(meeting, :invitations)
    |> order_by(:expires_at)
    |> Repo.all()
    |> Enum.filter(&(DateTime.compare(DateTime.utc_now(), &1.expires_at) == :lt))
  end

  @spec delete_invitation(Attendee.t(), integer()) ::
          {:ok, Invitation.t()} | {:error, :unauhorized} | {:error, Ecto.Changeset.t()}
  def delete_invitation(%Attendee{} = current_attendee, invitation_id) do
    with :ok <- ensure_is_admin(current_attendee) do
      Repo.get(Invitation, invitation_id)
      |> Repo.delete()
    end
  end

  defp ensure_is_admin(%Attendee{role: :admin}), do: :ok
  defp ensure_is_admin(%Attendee{} = _attendee), do: {:error, :unauthorized}

  defp ensure_is_not_self(%Attendee{} = current, %Attendee{} = other) when current.id == other.id,
    do: {:error, :unallowed_on_self}

  defp ensure_is_not_self(%Attendee{}, %Attendee{}),
    do: :ok
end
