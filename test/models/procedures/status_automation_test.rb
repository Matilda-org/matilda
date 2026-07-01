require "test_helper"

class Procedures::StatusAutomationTest < ActiveSupport::TestCase
  test "apply_on_item completes the task when typology is complete_task" do
    task = Task.create!(title: "Task", completed: false)
    item = Procedures::Item.create!(procedure_id: 1, procedures_status_id: 1, resource: task)
    automation = Procedures::StatusAutomation.new(procedures_status: procedures(:one).procedures_statuses.first, typology: :complete_task)

    assert automation.apply_on_item(item)
    assert task.reload.completed
  end

  test "apply_on_item uncompletes the task when typology is uncomplete_task" do
    task = Task.create!(title: "Task", completed: true)
    item = Procedures::Item.create!(procedure_id: 1, procedures_status_id: 1, resource: task)
    automation = Procedures::StatusAutomation.new(procedures_status: procedures(:one).procedures_statuses.first, typology: :uncomplete_task)

    assert automation.apply_on_item(item)
    assert_not task.reload.completed
  end

  test "apply_on_item clears the deadline when typology is cancel_deadline_task" do
    task = Task.create!(title: "Task", deadline: Date.today)
    item = Procedures::Item.create!(procedure_id: 1, procedures_status_id: 1, resource: task)
    automation = Procedures::StatusAutomation.new(procedures_status: procedures(:one).procedures_statuses.first, typology: :cancel_deadline_task)

    assert automation.apply_on_item(item)
    assert_nil task.reload.deadline
  end

  test "apply_on_item archives the project when typology is archive_project" do
    project = Project.create!(code: "AUTO-1", name: "Automated Project", year: 2024)
    item = Procedures::Item.create!(procedure_id: 3, procedures_status_id: 3, resource: project)
    automation = Procedures::StatusAutomation.new(procedures_status: procedures(:three).procedures_statuses.first, typology: :archive_project)

    assert automation.apply_on_item(item)
    assert project.reload.archived
  end

  test "apply_on_item does nothing when the procedure is a model" do
    task = Task.create!(title: "Task", completed: false)
    item = Procedures::Item.create!(procedure_id: 2, procedures_status_id: 2, resource: task)
    automation = Procedures::StatusAutomation.new(procedures_status: procedures(:two).procedures_statuses.first, typology: :complete_task)

    assert automation.apply_on_item(item)
    assert_not task.reload.completed
  end

  test "apply_on_item returns false and records the error when the item has no resource" do
    item = Procedures::Item.create!(procedure_id: 1, procedures_status_id: 1, title: "No resource")
    automation = Procedures::StatusAutomation.new(procedures_status: procedures(:one).procedures_statuses.first, typology: :complete_task)

    assert_not automation.apply_on_item(item)
    assert automation.errors[:base].present?
  end
end
