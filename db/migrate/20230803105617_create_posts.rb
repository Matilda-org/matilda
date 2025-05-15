class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.references :user, foreign_key: true
      t.string :content
      t.string :tags
      t.string :source_url
      t.timestamps
    end
  end
end
