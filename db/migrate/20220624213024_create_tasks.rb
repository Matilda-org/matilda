class CreateTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :tasks do |t|
      t.references :user, foreign_key: true
      t.string :title
      t.string :description
      t.string :output
      t.date :deadline
      t.integer :time_estimate
      t.integer :time_spent
      t.timestamps
    end
  end
end
