class CreateProjectsMembers < ActiveRecord::Migration[7.0]
  def change
    create_table :projects_members do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role
      t.timestamps
    end
  end
end
