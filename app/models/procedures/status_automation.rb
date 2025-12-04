class Procedures::StatusAutomation < ApplicationRecord
  include Cachable

  enum :typology, {
    unknown: 0,
    complete_task: 1,
    archive_project: 2,
    uncomplete_task: 3,
    order_deadline_asc_task: 4,
    # take_completed_task: 5, # NOTE: Lasciato per retrocompatibilità, non va più usato
    cancel_deadline_task: 6
    # take_uncompleted_task: 7, # NOTE: Lasciato per retrocompatibilità, non va più usato
    # take_daily_tasks: 8 # NOTE: Lasciato per retrocompatibilità, non va più usato
  }

  # RELATIONS
  ############################################################

  belongs_to :procedures_status, class_name: "Procedures::Status"

  # HOOKS
  ############################################################

  after_create :update_on_turbo_stream_kanban
  after_destroy :update_on_turbo_stream_kanban

  # HELPERS
  ############################################################

  def typology_complete_task?
    typology == "complete_task"
  end

  def typology_uncomplete_task?
    typology == "uncomplete_task"
  end

  def typology_cancel_deadline_task?
    typology == "cancel_deadline_task"
  end

  def typology_archive_project?
    typology == "archive_project"
  end

  def typology_order_deadline_asc_task?
    typology == "order_deadline_asc_task"
  end

  # OPERATIONS
  ############################################################

  def apply_on_item(item)
    ActiveRecord::Base.transaction do
      if typology_complete_task? && !procedures_status.procedure.model && procedures_status.procedure.resources_type_tasks?
        item.resource.update!(completed: true) unless item.resource.completed
      end

      if typology_uncomplete_task? && !procedures_status.procedure.model && procedures_status.procedure.resources_type_tasks?
        item.resource.update!(completed: false) if item.resource.completed
      end

      if typology_cancel_deadline_task? && !procedures_status.procedure.model && procedures_status.procedure.resources_type_tasks?
        item.resource.update!(deadline: nil) if item.resource.deadline
      end

      if typology_archive_project? && !procedures_status.procedure.model && procedures_status.procedure.resources_type_projects?
        item.resource.update!(archived: true) unless item.resource.archived
      end
    end

    true
  rescue StandardError => e
    puts "🚨" * 100
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end

  def update_on_turbo_stream_kanban
    procedures_status.update_on_turbo_stream_kanban
  end
end
