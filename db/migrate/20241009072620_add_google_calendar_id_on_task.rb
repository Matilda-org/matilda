class AddGoogleCalendarIdOnTask < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :google_calendar_id, :string
  end
end
