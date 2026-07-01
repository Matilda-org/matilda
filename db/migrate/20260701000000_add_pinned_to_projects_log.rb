class AddPinnedToProjectsLog < ActiveRecord::Migration[8.0]
  def change
    add_column :projects_logs, :pinned, :boolean, default: false
  end
end
