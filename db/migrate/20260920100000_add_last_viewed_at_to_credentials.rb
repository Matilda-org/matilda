class AddLastViewedAtToCredentials < ActiveRecord::Migration[8.0]
  def change
    add_column :credentials, :last_viewed_at, :datetime
  end
end
