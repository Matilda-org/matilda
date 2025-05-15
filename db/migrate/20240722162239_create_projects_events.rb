class CreateProjectsEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :projects_events do |t|
      t.references :project, null: false, foreign_key: true
      t.string :message
      t.json :data
      t.timestamps
    end
  end
end
