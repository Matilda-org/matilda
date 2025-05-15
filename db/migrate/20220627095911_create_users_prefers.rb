class CreateUsersPrefers < ActiveRecord::Migration[7.0]
  def change
    create_table :users_prefers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :resource, polymorphic: true
      t.timestamps
    end
  end
end
