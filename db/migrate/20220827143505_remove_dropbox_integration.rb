class RemoveDropboxIntegration < ActiveRecord::Migration[7.0]
  def change
    remove_column :projects, :dropbox_directory_id, :string
  end
end
