defmodule Core.MeetingsTest do
  use Core.DataCase, async: true
  import Core.Factory

  alias Core.Meetings
  alias Core.Meetings.Meeting

  describe "get_meeting/2" do
    test "returns meeting by id" do
      meeting = insert!(:meeting, title: "Team Standup")

      assert %Meeting{} = found = Meetings.get_meeting(meeting.id)
      assert found.id == meeting.id
      assert found.title == "Team Standup"
    end

    test "returns nil when meeting does not exist" do
      assert nil == Meetings.get_meeting(999_999)
    end

    test "preloads associations when requested" do
      meeting = insert!(:meeting)

      loaded = Meetings.get_meeting(meeting.id, preload: [:attendees])

      refute match?(%Ecto.Association.NotLoaded{}, loaded.attendees)
    end
  end

  describe "create_meeting/2" do
    test "creates meeting and adds creator as admin" do
      user = insert!(:user)

      assert {:ok, attendee} =
               Meetings.create_meeting(user, %{
                 "title" => "Team Sync",
                 "config" => %{"mode" => "week", "include_weekends" => true}
               })

      assert attendee.role == :admin
      assert attendee.user_id == user.id
      assert attendee.meeting.title == "Team Sync"
    end

    test "returns error with invalid attributes" do
      user = insert!(:user)

      assert {:error, changeset} = Meetings.create_meeting(user, %{title: nil})

      refute changeset.valid?
    end
  end

  describe "update_meeting/3" do
    setup do
      user = insert!(:user)
      meeting = insert!(:meeting)

      admin =
        insert!(:attendee,
          user: user,
          meeting: meeting,
          role: :admin
        )

      %{meeting: meeting, admin: admin}
    end

    test "admin can update meeting", %{admin: admin, meeting: meeting} do
      assert {:ok, updated} = Meetings.update_meeting(admin, meeting, %{title: "New Title"})

      assert updated.title == "New Title"
    end

    test "non-admin cannot update meeting", %{meeting: meeting} do
      user = insert!(:user)

      regular_attendee =
        insert!(:attendee,
          user: user,
          meeting: meeting,
          role: :user
        )

      assert {:error, :unauthorized} =
               Meetings.update_meeting(regular_attendee, meeting, %{title: "Hacked"})
    end

    test "returns error with invalid attributes", %{admin: admin, meeting: meeting} do
      assert {:error, changeset} = Meetings.update_meeting(admin, meeting, %{title: nil})

      refute changeset.valid?
    end
  end

  describe "delete_meeting/2" do
    setup do
      user = insert!(:user)
      meeting = insert!(:meeting)
      admin = insert!(:attendee, user: user, meeting: meeting, role: :admin)

      %{meeting: meeting, admin: admin}
    end

    test "admin can delete meeting", %{admin: admin, meeting: meeting} do
      assert {:ok, _deleted} = Meetings.delete_meeting(admin, meeting)

      assert nil == Meetings.get_meeting(meeting.id)
    end

    test "non-admin cannot delete meeting", %{meeting: meeting} do
      user = insert!(:user)
      regular_attendee = insert!(:attendee, user: user, meeting: meeting, role: :user)

      assert {:error, :unauthorized} = Meetings.delete_meeting(regular_attendee, meeting)
      assert Meetings.get_meeting(meeting.id)
    end
  end

  describe "list_meeting_attendees/2" do
    test "returns all attendees for a meeting" do
      user1 = insert!(:user)
      user2 = insert!(:user)
      meeting = insert!(:meeting)

      attendee1 = insert!(:attendee, user: user1, meeting: meeting, role: :admin)
      attendee2 = insert!(:attendee, user: user2, meeting: meeting, role: :user)

      attendees = Meetings.list_meeting_attendees(meeting)

      assert length(attendees) == 2
      assert attendee1.id in Enum.map(attendees, & &1.id)
      assert attendee2.id in Enum.map(attendees, & &1.id)
    end

    test "returns empty list when meeting has no attendees" do
      meeting = insert!(:meeting)

      assert [] == Meetings.list_meeting_attendees(meeting)
    end

    test "preloads associations when requested" do
      user = insert!(:user)
      meeting = insert!(:meeting)
      insert!(:attendee, user: user, meeting: meeting, role: :admin)

      [attendee] = Meetings.list_meeting_attendees(meeting, preload: [:user])

      assert attendee.user.id == user.id
    end

    test "orders attendees when specified" do
      meeting = insert!(:meeting)
      user1 = insert!(:user)
      user2 = insert!(:user)

      insert!(:attendee, user: user1, meeting: meeting, role: :admin)

      # Ensure different timestamps
      Process.sleep(10)

      insert!(:attendee, user: user2, meeting: meeting, role: :user)

      attendees = Meetings.list_meeting_attendees(meeting, order_by: [asc: :inserted_at])

      assert attendees |> Enum.at(0) |> Map.get(:user_id) == user1.id
      assert attendees |> Enum.at(1) |> Map.get(:user_id) == user2.id
    end
  end

  describe "get_attendee_by/2" do
    test "returns attendee by clauses" do
      user = insert!(:user)
      meeting = insert!(:meeting)
      attendee = insert!(:attendee, user: user, meeting: meeting, role: :admin)

      found = Meetings.get_attendee_by(user_id: user.id, meeting_id: meeting.id)

      assert found.id == attendee.id
    end

    test "returns nil when attendee does not exist" do
      assert nil == Meetings.get_attendee_by(user_id: 999_999, meeting_id: 999_999)
    end

    test "preloads associations when requested" do
      user = insert!(:user)
      meeting = insert!(:meeting)
      insert!(:attendee, user: user, meeting: meeting, role: :admin)

      attendee = Meetings.get_attendee_by([user_id: user.id], preload: [:user, :meeting])

      assert attendee.user.id == user.id
      assert attendee.meeting.id == meeting.id
    end
  end

  describe "check_if_already_joined/2" do
    test "returns attendee if user already joined" do
      user = insert!(:user)
      meeting = insert!(:meeting)
      attendee = insert!(:attendee, user: user, meeting: meeting, role: :admin)

      result = Meetings.check_if_already_joined(user, meeting)

      assert result.id == attendee.id
    end

    test "returns false if user has not joined" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      assert false == Meetings.check_if_already_joined(user, meeting)
    end
  end

  describe "join_meeting/3" do
    test "user can't join with invalid code" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      assert {:error, :invalid_code} = Meetings.join_meeting(user, meeting, "123456")
    end

    test "user can join meeting with valid code" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      insert!(:invitation, %{
        code: "464646",
        expires_at: DateTime.utc_now(:second) |> DateTime.shift(day: 1),
        meeting: meeting
      })

      assert {:ok, attendee} = Meetings.join_meeting(user, meeting, "464646")

      assert attendee.user_id == user.id
      assert attendee.meeting_id == meeting.id
      assert attendee.role == :user
      assert is_struct(attendee.config, Meetings.Attendee.Config.Week)
      assert attendee.config.available_days == []
    end

    test "user can't join with expired invitation" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      insert!(:invitation, %{
        code: "464646",
        expires_at: DateTime.utc_now(:second) |> DateTime.shift(day: -1),
        meeting: meeting
      })

      assert {:error, :expired} = Meetings.join_meeting(user, meeting, "464646")
    end
  end

  describe "update_attendee_role/3" do
    setup do
      user1 = insert!(:user)
      user2 = insert!(:user)
      meeting = insert!(:meeting)
      admin = insert!(:attendee, user: user1, meeting: meeting, role: :admin)
      regular = insert!(:attendee, user: user2, meeting: meeting, role: :user)

      %{admin: admin, regular: regular}
    end

    test "admin can update attendee role", %{admin: admin, regular: regular} do
      assert {:ok, updated} = Meetings.update_attendee_role(admin, regular, :admin)

      assert updated.role == :admin
    end

    test "non-admin cannot update attendee role", %{admin: admin, regular: regular} do
      assert {:error, :unauthorized} = Meetings.update_attendee_role(regular, admin, :user)
    end

    test "admin can demote another admin", %{admin: admin} do
      user = insert!(:user)
      meeting = Repo.preload(admin, :meeting).meeting
      other_admin = insert!(:attendee, user: user, meeting: meeting, role: :admin)

      assert {:ok, updated} = Meetings.update_attendee_role(admin, other_admin, :user)

      assert updated.role == :user
    end
  end

  describe "toggle_available_day/2" do
    test "adds day when not present" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      attendee =
        insert!(:attendee,
          user: user,
          meeting: meeting,
          role: :user,
          config: build(:attendee_config_week, available_days: [1, 2])
        )

      assert {:ok, updated} = Meetings.toggle_available_day(attendee, 3)

      assert 3 in updated.config.available_days
      assert length(updated.config.available_days) == 3
    end

    test "removes day when present" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      attendee =
        insert!(:attendee,
          user: user,
          meeting: meeting,
          role: :user,
          config: build(:attendee_config_week, available_days: [1, 2, 3])
        )

      assert {:ok, updated} = Meetings.toggle_available_day(attendee, 2)

      refute 2 in updated.config.available_days
      assert length(updated.config.available_days) == 2
    end

    test "can toggle same day multiple times" do
      user = insert!(:user)
      meeting = insert!(:meeting)
      attendee = insert!(:attendee, user: user, meeting: meeting, role: :user)

      {:ok, toggled_on} = Meetings.toggle_available_day(attendee, 2)
      assert 2 in toggled_on.config.available_days

      {:ok, toggled_off} = Meetings.toggle_available_day(toggled_on, 2)
      refute 2 in toggled_off.config.available_days
    end
  end

  describe "leave_meeting/1" do
    test "doesn't allow leaving as a last admin" do
      user = insert!(:user)
      meeting = insert!(:meeting)
      attendee = insert!(:attendee, user: user, meeting: meeting, role: :admin)

      assert {:error, :last_admin_cant_leave} = Meetings.leave_meeting(attendee)

      assert Meetings.get_meeting(meeting.id)
    end

    test "only deletes attendee when others remain" do
      user1 = insert!(:user)
      user2 = insert!(:user)
      meeting = insert!(:meeting)
      attendee1 = insert!(:attendee, user: user1, meeting: meeting, role: :admin)
      attendee2 = insert!(:attendee, user: user2, meeting: meeting, role: :user)

      assert {:ok, :leave} = Meetings.leave_meeting(attendee2)

      assert Meetings.get_meeting(meeting.id)
      assert nil == Meetings.get_attendee_by(id: attendee2.id)
      assert Meetings.get_attendee_by(id: attendee1.id)
    end
  end

  describe "kick_attendee/2" do
    setup do
      user1 = insert!(:user)
      user2 = insert!(:user)
      meeting = insert!(:meeting)
      admin = insert!(:attendee, user: user1, meeting: meeting, role: :admin)
      regular = insert!(:attendee, user: user2, meeting: meeting, role: :user)

      %{admin: admin, regular: regular, meeting: meeting}
    end

    test "admin can kick other attendee", %{admin: admin, regular: regular} do
      assert {:ok, _deleted} = Meetings.kick_attendee(admin, regular)

      assert nil == Meetings.get_attendee_by(id: regular.id)
    end

    test "non-admin cannot kick attendee", %{admin: admin, regular: regular} do
      assert {:error, :unauthorized} = Meetings.kick_attendee(regular, admin)

      assert Meetings.get_attendee_by(id: admin.id)
    end

    test "admin cannot kick themselves", %{admin: admin} do
      assert {:error, :unallowed_on_self} = Meetings.kick_attendee(admin, admin)

      assert Meetings.get_attendee_by(id: admin.id)
    end

    test "user cannot kick themselves", %{regular: regular} do
      assert {:error, :unauthorized} = Meetings.kick_attendee(regular, regular)
    end
  end

  describe "create_invitation/2" do
    test "creates invitation successfully" do
      meeting = insert!(:meeting)
      user = insert!(:user)
      current_attendee = insert!(:attendee, meeting: meeting, user: user, role: :admin)

      assert {:ok, _invitation} =
               Meetings.create_invitation(current_attendee, %{duration: "hour"})
    end

    test "fails if attendee is not admin" do
      meeting = insert!(:meeting)
      user = insert!(:user)
      current_attendee = insert!(:attendee, meeting: meeting, user: user, role: :user)

      assert {:error, :unauthorized} =
               Meetings.create_invitation(current_attendee, %{duration: "hour"})
    end
  end

  describe "list_meeting_invitations/1" do
    test "returns only active invitations" do
      meeting = insert!(:meeting)

      now = DateTime.utc_now(:second)

      insert!(:invitation,
        meeting: meeting,
        code: "123",
        expires_at: DateTime.shift(now, hour: 1)
      )

      insert!(:invitation,
        meeting: meeting,
        code: "123",
        expires_at: DateTime.shift(now, day: 1)
      )

      insert!(:invitation,
        meeting: meeting,
        code: "123",
        expires_at: DateTime.shift(now, month: 1)
      )

      invitation_expired =
        insert!(:invitation,
          meeting: meeting,
          code: "123",
          expires_at: DateTime.shift(now, day: -1)
        )

      invitations = Meetings.list_meeting_invitations(meeting)
      assert length(invitations) == 3
      assert not Enum.any?(invitations, &(&1.id == invitation_expired.id))
    end
  end

  describe "delete_invitation/2" do
    test "deletes invitation successfully" do
      meeting = insert!(:meeting)
      user = insert!(:user)
      current_attendee = insert!(:attendee, meeting: meeting, user: user, role: :admin)

      invitation =
        insert!(:invitation,
          meeting: meeting,
          code: "890",
          expires_at: DateTime.utc_now(:second) |> DateTime.shift(day: 1)
        )

      assert {:ok, _invitation} = Meetings.delete_invitation(current_attendee, invitation.id)
    end

    test "doesn't delete if attendee is not admin" do
      meeting = insert!(:meeting)
      user = insert!(:user)
      current_attendee = insert!(:attendee, meeting: meeting, user: user, role: :user)

      invitation =
        insert!(:invitation,
          meeting: meeting,
          code: "890",
          expires_at: DateTime.utc_now(:second) |> DateTime.shift(day: 1)
        )

      assert {:error, :unauthorized} = Meetings.delete_invitation(current_attendee, invitation.id)
    end
  end
end
