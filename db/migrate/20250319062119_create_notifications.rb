class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :typology, default: 0
      t.json :data
      t.boolean :managed, default: false
      t.timestamps
    end
  end
end
