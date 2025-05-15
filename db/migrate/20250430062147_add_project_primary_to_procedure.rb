class AddProjectPrimaryToProcedure < ActiveRecord::Migration[7.1]
  def change
    add_column :procedures, :project_primary, :boolean, default: false
  end
end
