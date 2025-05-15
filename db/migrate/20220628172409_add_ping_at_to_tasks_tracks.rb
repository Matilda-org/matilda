class AddPingAtToTasksTracks < ActiveRecord::Migration[7.0]
  def change
    add_column :tasks_tracks, :ping_at, :datetime
  end
end
