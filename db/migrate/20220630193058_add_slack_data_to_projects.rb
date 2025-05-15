class AddSlackDataToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :slack_channel_id, :string
  end
end
