class CreateCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :credentials do |t|
      t.string :name
      t.string :secure_username
      t.string :secure_password
      t.string :secure_content
      t.timestamps
    end
  end
end
