class CreatePresentations < ActiveRecord::Migration[7.0]
  def change
    create_table :presentations do |t|
      t.string :name
      t.string :description
      t.references :project, foreign_key: true
      t.integer :width_px
      t.integer :height_px
      t.timestamps
    end
  end
end
