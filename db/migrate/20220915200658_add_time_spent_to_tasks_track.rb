class AddTimeSpentToTasksTrack < ActiveRecord::Migration[7.0]
  def change
    add_column :tasks_tracks, :time_spent, :integer, default: 0
    change_column_default :tasks, :time_spent, from: nil, to: 0

    Tasks::Track.all.find_in_batches do |batch|
      batch.each do |track|
        duration = track.duration
        track.update_columns(time_spent: duration) if duration&.positive?
      end
    end
  end
end
