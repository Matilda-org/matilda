class AddUnresolvedToTask < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :unresolved, :boolean, default: false
  end
end
