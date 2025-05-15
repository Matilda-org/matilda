class RemoveShareExpirationFromProjectLogs < ActiveRecord::Migration[7.0]
  def change
    remove_column :projects_logs, :share_expiration
  end
end
