class CreateFoldersItems < ActiveRecord::Migration[7.0]
  def change
    create_table :folders_items do |t|
      t.references :resource, polymorphic: true
      t.references :folder, null: false
      t.timestamps
    end
  end
end
