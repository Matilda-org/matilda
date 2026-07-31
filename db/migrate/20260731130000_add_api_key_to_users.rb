# frozen_string_literal: true

# Per-user API key: API requests authenticate as a real user so data access
# policies apply to the API surface too (replaces the global functionalities_api_key setting).
class AddApiKeyToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :api_key, :string
    add_index :users, :api_key, unique: true

    # backfill existing users so every account can use the API immediately
    User.reset_column_information
    User.find_each { |user| user.update_column(:api_key, User.generate_unique_secure_token(length: 36)) }
  end

  def down
    remove_index :users, :api_key
    remove_column :users, :api_key
  end
end
