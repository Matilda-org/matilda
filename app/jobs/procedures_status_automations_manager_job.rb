# ProceduresStatusAutomationsManagerJob.
class ProceduresStatusAutomationsManagerJob < ApplicationJob
  def perform(procedure_id = nil)
    if procedure_id
      procedure = Procedure.find_by_id procedure_id
      return unless procedure

      perform_for_procedure(procedure)
      return
    end

    Procedure.find_each do |procedure|
      perform_for_procedure(procedure)
    end
  end

  private

  def perform_for_procedure(procedure)
    if procedure.resources_type_tasks?
      procedure.procedures_statuses.each do |status|
        if status.procedures_status_automations.find_by(typology: :take_daily_tasks)
          procedure.procedures_items.each do |item|
            task = item.resource
            next unless task && task.deadline && task.deadline <= Date.today && !task.completed

            item = task.procedures_items.find_by(procedure_id: procedure.id)
            next unless item

            item.move(status.id, status.procedures_items.count + 1)
          end
        end
      end
    end
  end
end
