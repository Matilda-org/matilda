class AddAcceptedToTask < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :accepted, :boolean, default: true
  end
end
