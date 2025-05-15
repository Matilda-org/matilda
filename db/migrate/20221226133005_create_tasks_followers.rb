class CreateTasksFollowers < ActiveRecord::Migration[7.0]
  def change
    create_table :tasks_followers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.timestamps
    end
  end
end
