class AddRepeatTypeToTask < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :repeat_type, :integer, default: 0, null: false
    add_column :tasks, :repeat_monthday, :integer, default: 0, null: false
  end
end
