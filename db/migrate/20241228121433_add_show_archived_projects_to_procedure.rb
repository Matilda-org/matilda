class AddShowArchivedProjectsToProcedure < ActiveRecord::Migration[7.1]
  def change
    add_column :procedures, :show_archived_projects, :boolean, default: false
  end
end
