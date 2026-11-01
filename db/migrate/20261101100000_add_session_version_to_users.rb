class AddSessionVersionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :session_version, :integer, default: 0, null: false
  end
end
