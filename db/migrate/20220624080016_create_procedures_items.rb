class CreateProceduresItems < ActiveRecord::Migration[7.0]
  def change
    create_table :procedures_items do |t|
      t.references :procedure, null: false, foreign_key: true
      t.references :procedures_status, null: false, foreign_key: true
      t.string :title
      t.integer :order, default: 1
      t.references :resource, polymorphic: true
      t.timestamps
    end
  end
end
