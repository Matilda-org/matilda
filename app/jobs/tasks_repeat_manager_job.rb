# TasksRepeatManagerJob.
class TasksRepeatManagerJob < ApplicationJob
  def perform(task_id = nil)
    if task_id
      task = Task.find_by_id task_id
      return unless task && task.repeat && task.repeat_to >= Date.today && task.repeat_from <= Date.today
      return perform_for_task(task)
    end

    Task.where(repeat: true).where('repeat_to >= ? AND repeat_from <= ?', Date.today, Date.today).each do |task|
      perform_for_task(task)
    end

    Task.where.not(repeat_original_task_id: nil).where('deadline >= ?', Date.today).find_each do |task|
      original_task = Task.find_by_id task.repeat_original_task_id

      task.destroy! unless original_task&.repeat
    end
  end

  private

  def perform_for_task(task)
    if task.repeat_type_weekly?
      (Date.today...14.days.from_now.to_date).each do |date|
        date_day_of_week_number = date.wday
        next unless task.repeat_weekdays&.include?(date_day_of_week_number)
        next if task.deadline == date

        perform_for_task_and_date(task, date)
      end
    end

    if task.repeat_type_monthly?
      (Date.today...90.days.from_now.to_date).each do |date|
        next if task.repeat_monthday_first? && date != date.beginning_of_month
        next if task.repeat_monthday_last? && date != date.end_of_month
        next if task.repeat_monthday_middle? && date != (date.beginning_of_month + 14.days)
        next if task.deadline == date

        perform_for_task_and_date(task, date)
      end
    end
  end

  def perform_for_task_and_date(task, date)
    return if task.repeat_from > date
    return if date > task.repeat_to

    data = {
      user_id: task.user_id,
      title: task.title,
      output: task.output,
      time_estimate: task.time_estimate,
      project_id: task.project_id,
      deadline: date,
      repeat_original_task_id: task.id
    }

    task_clone = Task.find_by(repeat_original_task_id: task.id, deadline: date)
    return if task_clone&.completed # ignore if task_clone exists and is already completed

    if task_clone
      task_clone.update_columns(data)
    else
      task_clone = Task.create!(data)
    end

    # clone tasks_followers
    task.tasks_followers.each do |tasks_follower|
      task_clone_follower = task_clone.tasks_followers.find_by(user_id: tasks_follower.user_id)
      next if task_clone_follower

      task_clone.tasks_followers.create!(user_id: tasks_follower.user_id)
    end
    task_clone.tasks_followers.where.not(user_id: task.tasks_followers.pluck(:user_id)).destroy_all

    # clone procedures_items
    task.procedures_items.each do |procedures_item|
      task_clone_item = task_clone.procedures_items.find_by(procedure_id: procedures_item.procedure_id, procedures_status_id: procedures_item.procedures_status_id)
      next if task_clone_item

      task_clone.procedures_items.create!(procedure_id: procedures_item.procedure_id, procedures_status_id: procedures_item.procedures_status_id, resource_type: 'Task', resource_id: task.id)
    end
    task_clone.procedures_items.where.not(procedure_id: task.procedures_items.pluck(:procedure_id), procedures_status_id: task.procedures_items.pluck(:procedures_status_id)).destroy_all
  end
end
