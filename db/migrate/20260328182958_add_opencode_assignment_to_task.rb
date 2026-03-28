class AddOpencodeAssignmentToTask < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :opencode_assignment, :boolean, default: false, null: false
  end
end
