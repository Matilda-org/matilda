# frozen_string_literal: true

require "test_helper"

class CommunicationTest < ActiveSupport::TestCase
  def build_communication
    campaigns(:one).communications.create!(contact: contacts(:one))
  end

  test "one communication per contact inside a campaign" do
    build_communication
    duplicate = campaigns(:one).communications.new(contact: contacts(:one))

    assert_not duplicate.valid?
  end

  test "mark_sent stores the sent date and requires it" do
    communication = build_communication

    assert_not communication.mark_sent(nil)
    assert communication.reload.to_send?

    assert communication.mark_sent(Date.new(2026, 8, 20))
    assert communication.sent?
    assert_equal Date.new(2026, 8, 20), communication.sent_date
  end

  test "mark_closed stores the closed date and accepts only lost or won" do
    communication = build_communication
    communication.mark_sent(Date.today - 5.days)

    assert_not communication.mark_closed("bogus", Date.today)
    assert_not communication.mark_closed("won", nil)
    assert communication.reload.sent?

    assert communication.mark_closed("won", Date.today)
    assert communication.won?
    assert_equal Date.today, communication.closed_date
  end

  test "confirmed dates are never rewritten by running a step twice" do
    communication = build_communication
    communication.mark_sent(Date.today - 5.days)

    assert_not communication.mark_sent(Date.today)
    assert_equal Date.today - 5.days, communication.reload.sent_date

    communication.mark_closed("won", Date.today - 2.days)
    assert_not communication.mark_closed("won", Date.today)
    assert_equal Date.today - 2.days, communication.reload.closed_date
  end

  test "states can never go back" do
    communication = build_communication

    # cannot skip the sent state
    assert_not communication.update(status: :won, sent_date: Date.today, closed_date: Date.today)

    communication.reload.mark_sent(Date.today - 5.days)
    assert_not communication.update(status: :to_send)

    communication.reload.mark_closed("lost", Date.today)
    assert_not communication.reload.update(status: :sent)
    assert_not communication.reload.update(status: :won)
    assert communication.reload.lost?
  end

  test "follow-ups count only while sent" do
    communication = build_communication

    assert_not communication.register_follow_up

    communication.mark_sent(Date.today)
    assert communication.register_follow_up
    assert communication.register_follow_up
    assert_equal 2, communication.reload.follow_ups_count

    communication.mark_closed("won", Date.today)
    assert_not communication.register_follow_up
  end
end
