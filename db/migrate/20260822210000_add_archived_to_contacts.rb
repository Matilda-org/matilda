class AddArchivedToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :archived, :boolean, default: false, null: false
  end
end
