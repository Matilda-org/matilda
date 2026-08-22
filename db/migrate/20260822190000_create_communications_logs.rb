class CreateCommunicationsLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :communications_logs do |t|
      t.references :communication, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.text :content, null: false

      t.timestamps
    end
  end
end
