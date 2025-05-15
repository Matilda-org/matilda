class AddDescriptionToProceduresStatuses < ActiveRecord::Migration[7.0]
  def change
    add_column :procedures_statuses, :description, :string
  end
end
