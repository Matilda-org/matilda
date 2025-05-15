class CreateProcedures < ActiveRecord::Migration[7.0]
  def change
    create_table :procedures do |t|
      t.string :name
      t.string :description
      t.integer :resources_type, default: 0
      t.boolean :archived, default: false
      t.boolean :model, default: false
      t.integer :items_count, default: 0
      t.integer :statuses_count, default: 0
      t.references :project, foreign_key: true
      t.timestamps
    end
  end
end
