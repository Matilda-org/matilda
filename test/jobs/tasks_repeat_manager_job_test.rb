require "test_helper"

class TasksRepeatManagerJobTest < ActiveSupport::TestCase
  def create_weekly_task
    # every weekday selected so clones are generated for the whole window
    Task.create!(
      title: "Weekly task",
      user: users(:one),
      repeat: true,
      repeat_type: :weekly,
      repeat_from: Date.today,
      repeat_to: 30.days.from_now.to_date,
      repeat_weekdays: [ 0, 1, 2, 3, 4, 5, 6 ],
      deadline: Date.today
    )
  end

  test "does nothing for a non repeating task id" do
    task = Task.create!(title: "One shot", user: users(:one))

    assert_no_difference "Task.count" do
      TasksRepeatManagerJob.perform_now(task.id)
    end
  end

  test "returns silently when task id does not exist" do
    assert_nothing_raised do
      TasksRepeatManagerJob.perform_now(9999)
    end
  end

  test "weekly repeat generates clones within the two week window" do
    task = create_weekly_task

    clones = Task.where(repeat_original_task_id: task.id)
    assert clones.any?

    clone = clones.first
    assert_equal task.title, clone.title
    assert_equal task.user_id, clone.user_id
    assert clone.deadline > Date.today
    assert clone.deadline <= 14.days.from_now.to_date
    # never clones onto the original deadline day
    assert_not_equal task.deadline, clone.deadline
  end

  test "does not overwrite an already completed clone" do
    task = create_weekly_task
    clone = Task.where(repeat_original_task_id: task.id).first
    clone.update_columns(completed: true, title: "Manually edited")

    TasksRepeatManagerJob.perform_now(task.id)

    clone.reload
    assert clone.completed
    assert_equal "Manually edited", clone.title
  end

  test "removes clones whose original no longer repeats" do
    task = create_weekly_task
    assert Task.where(repeat_original_task_id: task.id).any?

    # disable repeat without firing callbacks, then run the full scan
    task.update_columns(repeat: false)
    TasksRepeatManagerJob.perform_now

    assert_empty Task.where(repeat_original_task_id: task.id)
  end
end
