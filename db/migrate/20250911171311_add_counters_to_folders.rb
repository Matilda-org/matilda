class AddCountersToFolders < ActiveRecord::Migration[8.0]
  def change
    add_column :folders, :items_projects_count, :integer, default: 0, null: false
    add_column :folders, :items_credentials_count, :integer, default: 0, null: false

    Folder.all.each do |folder|
      folder.update_columns(
        items_projects_count: folder.folders_items.where(resource_type: "Project").count,
        items_credentials_count: folder.folders_items.where(resource_type: "Credential").count
      )
    end
  end
end
