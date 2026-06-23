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

  test "destroy_with_time_rollback! non porta time_spent sotto zero" do
    task = tasks(:one)
    track = task.tasks_tracks.create!(start_at: 1.hour.ago, end_at: Time.now, time_spent: 999_999, user: users(:one))

    track.destroy_with_time_rollback!

    assert task.reload.time_spent >= 0
  end
end
