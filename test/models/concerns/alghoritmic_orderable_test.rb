require "test_helper"

class AlghoritmicOrderableTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
    @procedure = Procedure.create!(name: "Board", resources_type: "projects")
    @status_low = @procedure.procedures_statuses.create!(title: "Low")   # order 1
    @status_high = @procedure.procedures_statuses.create!(title: "High") # order 2
  end

  test "recalculates alghoritmic_order from procedures items" do
    # two items, each with order 1, on statuses with order 1 and 2
    # values => [1*1, 1*2] => average 1.5 rounded to 2
    Procedures::Item.create!(procedure: @procedure, procedures_status: @status_low, resource: @project)
    Procedures::Item.create!(procedure: @procedure, procedures_status: @status_high, resource: @project)

    assert @project.alghoritmic_order_recalculate

    assert_equal 2, @project.reload.alghoritmic_order
  end

  test "does not update when the calculated order is unchanged" do
    Procedures::Item.create!(procedure: @procedure, procedures_status: @status_low, resource: @project)

    # single item order 1 * status order 1 => 1, equals the default
    assert @project.alghoritmic_order_recalculate
    assert_equal 1, @project.reload.alghoritmic_order
  end
end
