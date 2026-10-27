require "test_helper"

class Procedures::StatusTest < ActiveSupport::TestCase
  test "duplicate copies settings and automations next to the original" do
    procedure = procedures(:one)
    first = procedure.procedures_statuses.first
    first.update!(color: "#ff0000", description: "Desc")
    last = procedure.procedures_statuses.create!(title: "Last")
    first.add_automation(:complete_task)

    copy = first.duplicate

    assert copy.persisted?
    assert_equal "#{first.title} (copia)", copy.title
    assert_equal "#ff0000", copy.color
    assert_equal "Desc", copy.description
    assert_equal first.order + 1, copy.order
    assert_equal copy.order + 1, last.reload.order
    assert copy.automation?(:complete_task)
    assert first.procedures_items.any?
    assert_equal 0, copy.procedures_items.count
  end
end
