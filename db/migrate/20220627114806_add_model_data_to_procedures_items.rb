class AddModelDataToProceduresItems < ActiveRecord::Migration[7.0]
  def change
    add_column :procedures_items, :model_data, :json
  end
end
