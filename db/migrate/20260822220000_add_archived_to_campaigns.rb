class AddArchivedToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :archived, :boolean, default: false, null: false
  end
end
