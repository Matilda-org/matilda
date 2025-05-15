class CreateProjectsLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :projects_logs do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.date :date
      t.timestamps
    end
  end
end
