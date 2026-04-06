class RemoveOutputFromTask < ActiveRecord::Migration[8.0]
  def change
    remove_column :tasks, :output
  end
end
