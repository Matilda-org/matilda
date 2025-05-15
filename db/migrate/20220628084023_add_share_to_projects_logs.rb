class AddShareToProjectsLogs < ActiveRecord::Migration[7.0]
  def change
    add_column :projects_logs, :share_code, :string
    add_column :projects_logs, :share_expiration, :datetime
  end
end
