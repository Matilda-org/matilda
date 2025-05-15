class AddProjectToTask < ActiveRecord::Migration[7.0]
  def change
    add_reference :tasks, :project, foreign_key: true

    Task.all.each do |task|
      task.update_columns(project_id: task.procedure_as_item&.project_id)
    end
  end
end
