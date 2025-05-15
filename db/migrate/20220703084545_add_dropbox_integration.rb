class AddDropboxIntegration < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :dropbox_directory_id, :string
  end
end
