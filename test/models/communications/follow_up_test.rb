# frozen_string_literal: true

require "test_helper"

class Communications::FollowUpTest < ActiveSupport::TestCase
  def communication
    @communication ||= campaigns(:one).communications.create!(contact: contacts(:one))
  end

  test "register_follow_up creates a dated record and keeps the counter in sync" do
    communication.mark_sent(Date.today - 10.days)

    follow_up = communication.register_follow_up(Date.today - 3.days, users(:one))
    assert_equal Date.today - 3.days, follow_up.date
    assert_equal users(:one).id, follow_up.user_id
    assert_equal 1, communication.reload.follow_ups_count

    communication.register_follow_up
    assert_equal Date.today, communication.communications_follow_ups.recent_first.first.date
    assert_equal 2, communication.reload.follow_ups_count
  end

  test "a follow-up can be undone and the counter goes back" do
    communication.mark_sent(Date.today - 10.days)
    follow_up = communication.register_follow_up
    assert_equal 1, communication.reload.follow_ups_count

    follow_up.destroy
    assert_equal 0, communication.reload.follow_ups_count
  end

  test "follow-ups are only allowed while waiting for an outcome" do
    assert_not communication.register_follow_up
    assert_equal 0, communication.communications_follow_ups.count

    communication.mark_sent(Date.today)
    assert communication.register_follow_up

    communication.mark_closed("won", Date.today)
    assert_not communication.register_follow_up
    assert_equal 1, communication.reload.follow_ups_count
  end
end
