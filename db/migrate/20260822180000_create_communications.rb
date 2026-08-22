class CreateCommunications < ActiveRecord::Migration[8.0]
  def change
    create_table :communications do |t|
      t.references :contact, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.integer :follow_ups_count, default: 0, null: false
      # confirmed when moving to "sent"
      t.date :sent_date
      # confirmed when moving to "lost" or "won"
      t.date :closed_date

      t.timestamps
    end

    # one communication per contact inside a campaign
    add_index :communications, [ :campaign_id, :contact_id ], unique: true
  end
end
