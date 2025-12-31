defmodule Core.Meetings do
  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Meetings.Meeting
  alias Core.Meetings.Attendee
  alias Core.Meetings.Invitation

  def get_meeting(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    Meeting
    |> Repo.get(id)
    |> Repo.preload(preload)
  end

  def create_meeting!(attrs \\ %{}) do
    %Meeting{}
    |> Meeting.changeset(attrs)
    |> Repo.insert!()
  end

  def update_meeting!(%Meeting{} = meeting, attrs) do
    meeting
    |> Meeting.changeset(attrs)
    |> Repo.update!()
  end

  def delete_meeting!(%Meeting{} = meeting) do
    Repo.delete!(meeting)
  end

  def get_attendee(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    Attendee
    |> Repo.get(id)
    |> Repo.preload(preload)
  end

  def get_attendee_by(clauses, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    Attendee
    |> Repo.get_by(clauses)
    |> Repo.preload(preload)
  end

  def create_attendee!(attrs \\ %{}) do
    %Attendee{}
    |> Attendee.changeset(attrs)
    |> Repo.insert!()
  end

  def update_attendee!(%Attendee{} = attendee, attrs) do
    attendee
    |> Attendee.changeset(attrs)
    |> Repo.update!()
  end

  def delete_attendee!(%Attendee{} = attendee) do
    Repo.delete!(attendee)
  end

  def get_invitation(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    Invitation
    |> Repo.get(id)
    |> Repo.preload(preload)
  end

  def get_invitation_by(clauses, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    Invitation
    |> Repo.get_by(clauses)
    |> Repo.preload(preload)
  end

  def create_invitation!(attrs \\ %{}) do
    %Invitation{}
    |> Invitation.changeset(attrs)
    |> Repo.insert!()
  end

  def update_invitation!(%Invitation{} = invitation, attrs) do
    invitation
    |> Invitation.changeset(attrs)
    |> Repo.update!()
  end

  def delete_invitation!(%Invitation{} = invitation) do
    Repo.delete!(invitation)
  end

  def add_attendee_to_meeting!(%Meeting{} = meeting, %Core.Auth.User{} = user, attrs \\ %{}) do
    # Check if this is the first attendee (creator)
    is_first =
      Repo.aggregate(from(a in Attendee, where: a.meeting_id == ^meeting.id), :count) == 0

    attrs =
      attrs
      |> Map.put_new(:role, if(is_first, do: :admin, else: :user))
      |> Map.put_new(:available_days, [])

    %Attendee{}
    |> Attendee.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:meeting, meeting)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert!()
  end
end
