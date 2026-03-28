class CreateTasksComments < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks_comments do |t|
      t.references :task, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :service
      t.text :content
      t.timestamps
    end
  end
end
