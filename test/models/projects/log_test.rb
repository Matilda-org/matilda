require "test_helper"

class Projects::LogTest < ActiveSupport::TestCase
  test "pinned_first orders pinned logs before unpinned ones" do
    project = projects(:one)
    unpinned = project.projects_logs.create!(title: "Unpinned", date: Date.today, user_id: users(:one).id)
    pinned = project.projects_logs.create!(title: "Pinned", date: Date.yesterday, user_id: users(:one).id, pinned: true)

    ordered = project.projects_logs.pinned_first.to_a
    assert_equal pinned, ordered.first
    assert ordered.index(pinned) < ordered.index(unpinned)
  end
end
