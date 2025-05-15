class CreatePresentationsActions < ActiveRecord::Migration[7.0]
  def change
    create_table :presentations_actions do |t|
      t.references :presentation, null: false, foreign_key: true
      t.references :presentations_page, null: false, foreign_key: true
      t.float :position_x, default: 0.0
      t.float :position_y, default: 0.0

      t.integer :page_destination
      t.timestamps
    end
  end
end
