class CreateProjects < ActiveRecord::Migration[7.0]
  def change
    create_table :projects do |t|
      t.string :code, null: false, index: { unique: true }
      t.string :name
      t.string :description
      t.boolean :archived, default: false
      t.integer :archived_reason, default: 0
      t.integer :year, limit: 4
      t.timestamps
    end
  end
end
