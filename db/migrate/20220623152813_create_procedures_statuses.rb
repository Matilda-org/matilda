class CreateProceduresStatuses < ActiveRecord::Migration[7.0]
  def change
    create_table :procedures_statuses do |t|
      t.references :procedure, null: false, foreign_key: true
      t.string :title
      t.integer :order, default: 1
      t.integer :items_count, default: 0
      t.timestamps
    end
  end
end
