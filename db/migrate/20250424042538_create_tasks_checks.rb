class CreateTasksChecks < ActiveRecord::Migration[7.1]
  def change
    create_table :tasks_checks do |t|
      t.references :task, null: false, foreign_key: true
      t.string :text
      t.boolean :checked, default: false
      t.integer :order, default: 1
      t.timestamps
    end
  end
end
