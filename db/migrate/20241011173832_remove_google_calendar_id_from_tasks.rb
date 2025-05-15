class RemoveGoogleCalendarIdFromTasks < ActiveRecord::Migration[7.1]
  def change
    remove_column :tasks, :google_calendar_id
  end
end
