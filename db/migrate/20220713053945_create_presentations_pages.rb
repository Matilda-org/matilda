class CreatePresentationsPages < ActiveRecord::Migration[7.0]
  def change
    create_table :presentations_pages do |t|
      t.references :presentation, null: false, foreign_key: true
      t.string :title
      t.string :image_name
      t.integer :order, default: 1
      t.timestamps
    end
  end
end
