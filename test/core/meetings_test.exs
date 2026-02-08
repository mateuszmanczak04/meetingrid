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

      assert {:ok, attendee} = Meetings.create_meeting(user, %{title: "Team Sync"})

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
      admin = insert!(:attendee, user: user, meeting: meeting, role: :admin, available_days: [1])

      %{meeting: meeting, admin: admin}
    end

    test "admin can update meeting", %{admin: admin, meeting: meeting} do
      assert {:ok, updated} = Meetings.update_meeting(admin, meeting, %{title: "New Title"})

      assert updated.title == "New Title"
    end

    test "non-admin cannot update meeting", %{meeting: meeting} do
      user = insert!(:user)

      regular_attendee =
        insert!(:attendee, user: user, meeting: meeting, role: :user, available_days: [1])

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
      admin = insert!(:attendee, user: user, meeting: meeting, role: :admin, available_days: [1])

      %{meeting: meeting, admin: admin}
    end

    test "admin can delete meeting", %{admin: admin, meeting: meeting} do
      assert {:ok, _deleted} = Meetings.delete_meeting(admin, meeting)

      assert nil == Meetings.get_meeting(meeting.id)
    end

    test "non-admin cannot delete meeting", %{meeting: meeting} do
      user = insert!(:user)

      regular_attendee =
        insert!(:attendee, user: user, meeting: meeting, role: :user, available_days: [1])

      assert {:error, :unauthorized} = Meetings.delete_meeting(regular_attendee, meeting)
      assert Meetings.get_meeting(meeting.id)
    end
  end

  describe "list_meeting_attendees/2" do
    test "returns all attendees for a meeting" do
      user1 = insert!(:user)
      user2 = insert!(:user)
      meeting = insert!(:meeting)

      attendee1 =
        insert!(:attendee, user: user1, meeting: meeting, role: :admin, available_days: [1])

      attendee2 =
        insert!(:attendee, user: user2, meeting: meeting, role: :user, available_days: [2])

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
      insert!(:attendee, user: user, meeting: meeting, role: :admin, available_days: [1])

      [attendee] = Meetings.list_meeting_attendees(meeting, preload: [:user])

      assert attendee.user.id == user.id
    end

    test "orders attendees when specified" do
      meeting = insert!(:meeting)
      user1 = insert!(:user)
      user2 = insert!(:user)

      insert!(:attendee, user: user1, meeting: meeting, role: :admin, available_days: [1])

      # Ensure different timestamps
      Process.sleep(10)

      insert!(:attendee, user: user2, meeting: meeting, role: :user, available_days: [2])

      attendees = Meetings.list_meeting_attendees(meeting, order_by: [asc: :inserted_at])

      assert attendees |> Enum.at(0) |> Map.get(:user_id) == user1.id
      assert attendees |> Enum.at(1) |> Map.get(:user_id) == user2.id
    end
  end

  describe "get_attendee_by/2" do
    test "returns attendee by clauses" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      attendee =
        insert!(:attendee, user: user, meeting: meeting, role: :admin, available_days: [1])

      found = Meetings.get_attendee_by(user_id: user.id, meeting_id: meeting.id)

      assert found.id == attendee.id
    end

    test "returns nil when attendee does not exist" do
      assert nil == Meetings.get_attendee_by(user_id: 999_999, meeting_id: 999_999)
    end

    test "preloads associations when requested" do
      user = insert!(:user)
      meeting = insert!(:meeting)
      insert!(:attendee, user: user, meeting: meeting, role: :admin, available_days: [1])

      attendee = Meetings.get_attendee_by([user_id: user.id], preload: [:user, :meeting])

      assert attendee.user.id == user.id
      assert attendee.meeting.id == meeting.id
    end
  end

  describe "check_if_already_joined/2" do
    test "returns attendee if user already joined" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      attendee =
        insert!(:attendee, user: user, meeting: meeting, role: :admin, available_days: [1])

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
    test "user can join meeting" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      assert {:ok, attendee} =
               Meetings.join_meeting(user, meeting, %{
                 role: :user,
                 available_days: [1, 3, 5]
               })

      assert attendee.user_id == user.id
      assert attendee.meeting_id == meeting.id
      assert attendee.role == :user
      assert attendee.available_days == [1, 3, 5]
    end

    test "returns error with invalid attributes" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      assert {:error, changeset} = Meetings.join_meeting(user, meeting, %{})

      refute changeset.valid?
    end
  end

  describe "update_attendee_role/3" do
    setup do
      user1 = insert!(:user)
      user2 = insert!(:user)
      meeting = insert!(:meeting)
      admin = insert!(:attendee, user: user1, meeting: meeting, role: :admin, available_days: [1])

      regular =
        insert!(:attendee, user: user2, meeting: meeting, role: :user, available_days: [2])

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

      other_admin =
        insert!(:attendee, user: user, meeting: meeting, role: :admin, available_days: [1])

      assert {:ok, updated} = Meetings.update_attendee_role(admin, other_admin, :user)

      assert updated.role == :user
    end
  end

  describe "toggle_available_day/2" do
    test "adds day when not present" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      attendee =
        insert!(:attendee, user: user, meeting: meeting, role: :user, available_days: [1, 2])

      assert {:ok, updated} = Meetings.toggle_available_day(attendee, 3)

      assert 3 in updated.available_days
      assert length(updated.available_days) == 3
    end

    test "removes day when present" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      attendee =
        insert!(:attendee, user: user, meeting: meeting, role: :user, available_days: [1, 2, 3])

      assert {:ok, updated} = Meetings.toggle_available_day(attendee, 2)

      refute 2 in updated.available_days
      assert length(updated.available_days) == 2
    end

    test "can toggle same day multiple times" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      attendee =
        insert!(:attendee, user: user, meeting: meeting, role: :user, available_days: [1])

      {:ok, toggled_on} = Meetings.toggle_available_day(attendee, 2)
      assert 2 in toggled_on.available_days

      {:ok, toggled_off} = Meetings.toggle_available_day(toggled_on, 2)
      refute 2 in toggled_off.available_days
    end
  end

  describe "leave_meeting/1" do
    test "doesn't allow leaving as a last admin" do
      user = insert!(:user)
      meeting = insert!(:meeting)

      attendee =
        insert!(:attendee, user: user, meeting: meeting, role: :admin, available_days: [1])

      assert {:error, :last_admin_cant_leave} = Meetings.leave_meeting(attendee)

      assert Meetings.get_meeting(meeting.id)
    end

    test "only deletes attendee when others remain" do
      user1 = insert!(:user)
      user2 = insert!(:user)
      meeting = insert!(:meeting)

      attendee1 =
        insert!(:attendee, user: user1, meeting: meeting, role: :admin, available_days: [1])

      attendee2 =
        insert!(:attendee, user: user2, meeting: meeting, role: :user, available_days: [2])

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
      admin = insert!(:attendee, user: user1, meeting: meeting, role: :admin, available_days: [1])

      regular =
        insert!(:attendee, user: user2, meeting: meeting, role: :user, available_days: [2])

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
end
