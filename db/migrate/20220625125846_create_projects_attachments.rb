class CreateProjectsAttachments < ActiveRecord::Migration[7.0]
  def change
    create_table :projects_attachments do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :typology, default: 0
      t.string :title
      t.string :description
      t.integer :version
      t.date :date
      t.timestamps
    end
  end
end
