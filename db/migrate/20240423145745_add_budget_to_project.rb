class AddBudgetToProject < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :budget_management, :boolean, default: false
    add_column :projects, :budget_money, :integer, default: 0
    add_column :projects, :budget_time, :integer, default: 0
  end
end
