defmodule Core.Meetings.MeetingServerTest do
  use Core.GenServerCase
  import Core.Factory

  alias Core.Meetings.MeetingServer
  alias Core.Meetings

  test "server shuts down when deleting meeting" do
    user = insert!(:user)
    meeting = insert!(:meeting)
    admin = insert!(:attendee, user: user, meeting: meeting, role: :admin)

    MeetingServer.check_if_already_joined(meeting.id, user)

    [{pid, _}] = Registry.lookup(MeetingServer.registry_name(), meeting.id)
    ref = Process.monitor(pid)

    MeetingServer.delete_meeting(meeting.id, admin)

    assert_receive {:DOWN, ^ref, :process, ^pid, :shutdown}
  end

  test "broadcasts state updates" do
    user = insert!(:user)
    meeting = insert!(:meeting)

    Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{meeting.id}")

    MeetingServer.join_meeting(meeting.id, user)

    assert_receive {:state_updated, state}
    assert length(state.attendees) == 1
  end

  test "calculates common days from all attendees" do
    user1 = insert!(:user)
    user2 = insert!(:user)
    meeting_config = build(:meeting_config_week)
    meeting = insert!(:meeting, config: meeting_config)

    attendee_config1 = build(:attendee_config_week, available_days: [1, 2, 3])
    insert!(:attendee, user: user1, meeting: meeting, role: :admin, config: attendee_config1)

    attendee_config2 = build(:attendee_config_week, available_days: [2, 3, 4])
    insert!(:attendee, user: user2, meeting: meeting, role: :user, config: attendee_config2)

    {_attendee, state} = MeetingServer.check_if_already_joined(meeting.id, user1)

    assert Enum.sort(state.common_days) == [2, 3]
  end

  test "calculates common hours from all attendees for config: Meetings.Meeting.Config.Day" do
    user1 = insert!(:user)
    user2 = insert!(:user)
    meeting_config = build(:meeting_config_day)
    meeting = insert!(:meeting, config: meeting_config)

    attendee_config1 = build(:attendee_config_day, available_hours: [9, 10, 11, 12])
    insert!(:attendee, user: user1, meeting: meeting, role: :admin, config: attendee_config1)

    attendee_config2 = build(:attendee_config_day, available_hours: [10, 11, 12, 13])
    insert!(:attendee, user: user2, meeting: meeting, role: :user, config: attendee_config2)

    {_attendee, state} = MeetingServer.check_if_already_joined(meeting.id, user1)

    assert Enum.sort(state.common_hours) == [10, 11, 12]
  end

  test "complete flow: join, toggle day, leave" do
    user = insert!(:user)
    meeting_config = build(:meeting_config_week)
    meeting = insert!(:meeting, config: meeting_config)

    MeetingServer.join_meeting(meeting.id, user)

    attendee = Meetings.get_attendee_by(user_id: user.id, meeting_id: meeting.id)

    Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{meeting.id}")

    MeetingServer.toggle_available_day(meeting.id, attendee, 1)

    assert_receive {:state_updated, _state}, 100

    updated = Meetings.get_attendee_by(id: attendee.id)
    assert 1 in updated.config.available_days

    assert :ok = MeetingServer.leave_meeting(meeting.id, updated)
  end

  test "invalid operations don't crash server" do
    user = insert!(:user)
    meeting = insert!(:meeting)
    regular = insert!(:attendee, user: user, meeting: meeting, role: :user)

    # Non-admin tries admin action
    MeetingServer.update_meeting(meeting.id, regular, %{title: "Hacked"})

    # Server still works
    assert {_attendee, _state} = MeetingServer.check_if_already_joined(meeting.id, user)
  end

  test "kicked attendee receives notification" do
    user1 = insert!(:user)
    user2 = insert!(:user)
    meeting = insert!(:meeting)
    admin = insert!(:attendee, user: user1, meeting: meeting, role: :admin)
    regular = insert!(:attendee, user: user2, meeting: meeting, role: :user)

    Phoenix.PubSub.subscribe(Core.PubSub, "attendee:#{regular.id}")
    Phoenix.PubSub.subscribe(Core.PubSub, "meeting:#{meeting.id}")

    MeetingServer.kick_attendee(meeting.id, admin, regular)

    assert_receive :you_were_kicked

    assert_receive {:state_updated, _state}, 100
  end
end
