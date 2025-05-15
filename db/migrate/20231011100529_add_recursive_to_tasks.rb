class AddRecursiveToTasks < ActiveRecord::Migration[7.0]
  def change
    add_column :tasks, :repeat, :boolean, default: false
    add_column :tasks, :repeat_from, :date
    add_column :tasks, :repeat_to, :date
    add_column :tasks, :repeat_weekdays, :json, default: []
    add_column :tasks, :repeat_original_task_id, :integer
  end
end
