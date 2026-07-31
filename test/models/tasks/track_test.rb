require "test_helper"

class Tasks::TrackTest < ActiveSupport::TestCase
  test "destroy_with_time_rollback! sottrae il tempo dal task ed elimina il track" do
    task = tasks(:one)
    before = task.time_spent
    track = task.tasks_tracks.create!(start_at: 1.hour.ago, end_at: Time.now, time_spent: 3600, user: users(:one))
    task.update_columns(time_spent: before + 3600)

    track.destroy_with_time_rollback!

    assert_not Tasks::Track.exists?(track.id)
    assert_equal before, task.reload.time_spent
  end

  test "move_to_date! sposta il track mantenendo ora e durata" do
    task = tasks(:one)
    start_at = 3.days.ago.change(hour: 10, min: 30)
    track = task.tasks_tracks.create!(start_at: start_at, end_at: start_at + 3600, ping_at: start_at, time_spent: 3600, user: users(:one))
    before = task.reload.time_spent

    track.move_to_date!(Date.current + 5.days)
    track.reload

    assert_equal Date.current + 5.days, track.start_at.to_date
    assert_equal [ 10, 30 ], [ track.start_at.hour, track.start_at.min ]
    assert_equal 3600, (track.end_at - track.start_at).to_i
    assert_equal 3600, track.time_spent
    assert_equal before, task.reload.time_spent
  end

  test "move_to_date! sposta anche i track aperti" do
    task = tasks(:one)
    start_at = 1.hour.ago
    track = task.tasks_tracks.create!(start_at: start_at, user: users(:one))
    # ping_at is forced to start_at on create, simulate 10 minutes of pings
    track.update_columns(ping_at: start_at + 600)

    track.move_to_date!(Date.current - 2.days)
    track.reload

    assert_equal Date.current - 2.days, track.start_at.to_date
    assert_nil track.end_at
    assert_equal 600, (track.ping_at - track.start_at).to_i
  end

  test "destroy_with_time_rollback! non porta time_spent sotto zero" do
    task = tasks(:one)
    track = task.tasks_tracks.create!(start_at: 1.hour.ago, end_at: Time.now, time_spent: 999_999, user: users(:one))

    track.destroy_with_time_rollback!

    assert task.reload.time_spent >= 0
  end
end
