class AddAlghoritmicOrderToTaskAndProject < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :alghoritmic_order, :integer, default: 1
    add_column :projects, :alghoritmic_order, :integer, default: 1
  end
end
