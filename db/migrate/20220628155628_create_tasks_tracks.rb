class CreateTasksTracks < ActiveRecord::Migration[7.0]
  def change
    create_table :tasks_tracks do |t|
      t.references :task, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.datetime :start_at
      t.datetime :end_at
      t.timestamps
    end
  end
end
