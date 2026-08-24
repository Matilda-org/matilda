# frozen_string_literal: true

require "test_helper"

class Communications::LogTest < ActiveSupport::TestCase
  def communication
    @communication ||= campaigns(:one).communications.create!(contact: contacts(:one))
  end

  test "content is rich text and cannot be blank" do
    assert_not communication.communications_logs.new(content: "").valid?
    assert_not communication.communications_logs.new(content: "<div>   </div>").valid?

    log = communication.communications_logs.create!(content: "<div>Prima <strong>nota</strong></div>")
    assert_equal "Prima nota", log.content.to_plain_text
  end
end
