class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.string :name, null: false
      t.string :vat_number
      t.string :email
      t.string :phone
      t.string :website
      t.string :address
      t.text :description

      t.timestamps
    end
  end
end
