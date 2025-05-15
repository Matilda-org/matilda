class CreateUsersLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :users_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :typology, null: false, default: 0
      t.string :value
      t.timestamps
    end
  end
end
