class AddColorToProcedureStatus < ActiveRecord::Migration[8.0]
  def change
    add_column :procedures_statuses, :color, :string
  end
end
