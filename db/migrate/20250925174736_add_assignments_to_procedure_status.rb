class AddAssignmentsToProcedureStatus < ActiveRecord::Migration[8.0]
  def change
    add_column :procedures_statuses, :assignment_user_id, :integer
    add_column :procedures_statuses, :follow_user_id, :integer
  end
end
