class RemoveProjectsRepositories < ActiveRecord::Migration[8.1]
  # Users::Policy no longer maps 63 (projects_manage_repositories): rows left
  # behind would read back as a nil policy.
  REPOSITORIES_POLICY = 63

  def up
    execute "DELETE FROM users_policies WHERE policy = #{REPOSITORIES_POLICY}"
    drop_table :projects_repositories
  end

  def down
    create_table :projects_repositories do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :provider
      t.string :url, null: false
      t.string :name
      t.string :default_branch
      t.timestamps
    end

    add_index :projects_repositories, [ :project_id, :url ], unique: true
  end
end
