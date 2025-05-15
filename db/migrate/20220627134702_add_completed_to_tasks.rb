class AddCompletedToTasks < ActiveRecord::Migration[7.0]
  def change
    add_column :tasks, :completed, :boolean, default: false
    add_column :tasks, :completed_at, :datetime
  end
end
