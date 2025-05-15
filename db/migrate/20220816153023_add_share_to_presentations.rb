class AddShareToPresentations < ActiveRecord::Migration[7.0]
  def change
    add_column :presentations, :share_code, :string
  end
end
