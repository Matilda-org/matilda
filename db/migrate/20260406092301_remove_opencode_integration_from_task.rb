class RemoveOpencodeIntegrationFromTask < ActiveRecord::Migration[8.0]
  def change
    remove_column :tasks, :opencode_assignment
  end
end
