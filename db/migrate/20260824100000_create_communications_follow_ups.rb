class CreateCommunicationsFollowUps < ActiveRecord::Migration[8.0]
  def change
    create_table :communications_follow_ups do |t|
      t.references :communication, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.date :date, null: false

      t.timestamps
    end

    # the old plain counter carried no date: it becomes the counter cache of the
    # new records, so it restarts from zero
    reversible do |dir|
      dir.up { execute "UPDATE communications SET follow_ups_count = 0" }
    end
  end
end
