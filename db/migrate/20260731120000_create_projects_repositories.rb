class CreateProjectsRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :projects_repositories do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :provider, default: 0
      t.string :url, null: false
      t.string :name
      t.string :default_branch
      t.timestamps
    end

    add_index :projects_repositories, [ :project_id, :url ], unique: true
  end
end
