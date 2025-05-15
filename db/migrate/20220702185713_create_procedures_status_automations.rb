class CreateProceduresStatusAutomations < ActiveRecord::Migration[7.0]
  def change
    create_table :procedures_status_automations do |t|
      t.references :procedures_status, null: false, foreign_key: true
      t.integer :typology, default: 0
      t.json :data
      t.timestamps
    end
  end
end
