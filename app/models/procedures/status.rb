class Procedures::Status < ApplicationRecord
  include Cachable

  # HACK: to work on ToolsController.projects_tasks_tracking
  attr_accessor :time_spent

  # VALIDATIONS
  ############################################################

  validates :title, presence: true, length: { maximum: 50 }

  # RELATIONS
  ############################################################

  belongs_to :procedure, counter_cache: true, class_name: "Procedure"
  has_many :procedures_items, dependent: :destroy, class_name: "Procedures::Item", foreign_key: :procedures_status_id
  has_many :procedures_status_automations, dependent: :destroy, class_name: "Procedures::StatusAutomation", foreign_key: :procedures_status_id

  # HOOKS
  ############################################################

  before_validation do
    self.title = capitalize_first_char(title) if title.present?
  end

  before_create do
    default_order = (procedure.procedures_statuses.pluck(:order).max || 0) + 1
    self.order = default_order
  end

  # Rienero il campo order di tutti gli stati rimasti per lo stessa board.
  after_destroy do
    procedure.procedures_statuses.order(:order).each_with_index do |status, index|
      status.update_columns(order: index)
    end
  end

  # QUESTIONS
  ############################################################

  def can_move?(direction)
    return false unless direction.in?(%w[left right left-full right-full])

    if direction.in?(%w[left-full right-full])
      return false if direction == "left-full" && self.id == procedure.procedures_statuses.order(:order).first.id
      return false if direction == "right-full" && self.id == procedure.procedures_statuses.order(:order).last.id

      true
    else
      new_order = direction == "left" ? order - 1 : order + 1
      max_order = procedure.procedures_statuses.pluck(:order).max
      min_order = 1

      new_order <= max_order && new_order >= min_order
    end
  end

  def automation?(automation)
    !!procedures_status_automations.find_by(typology: automation&.to_sym)
  end

  # HELPERS
  ############################################################

  def procedures_items_ordered_and_filtered
    # show tasks ordered by deadline and completed if automation is active
    if procedures_status_automations.find_by(typology: "order_deadline_asc_task") && !procedure.model
      return procedures_items.joins("JOIN tasks ON tasks.id = procedures_items.resource_id AND procedures_items.resource_type = 'Task'").order("tasks.completed ASC, tasks.deadline ASC")
    end

    # hide archived projects if show_archived_projects is false
    if procedure.resources_type_projects? && !procedure.show_archived_projects && !procedure.model
      return procedures_items.joins("JOIN projects ON projects.id = procedures_items.resource_id AND procedures_items.resource_type = 'Project'").where("projects.archived = false").order(order: :asc)
    end

    procedures_items.order(order: :asc)
  end

  # OPERATIONS
  ############################################################

  def move(direction)
    unless can_move?(direction)
      errors.add(:direction, "Spostamento non disponibile")
      return false
    end

    ActiveRecord::Base.transaction do
      if direction.in?(%w[left-full right-full])
        new_order = direction == "left-full" ? 1 : procedure.procedures_statuses.pluck(:order).max

        update!(order: new_order)
        procedure.procedures_statuses.where.not(id: id).order(:order).each_with_index do |status, index|
          status.update_columns(order: index + (direction == "left-full" ? 2 : 1))
        end
      else
        current_order = order
        new_order = direction == "left" ? order - 1 : order + 1

        procedure.procedures_statuses.find_by(order: new_order).update_columns(order: current_order)
        update!(order: new_order)
      end
    end

    true
  rescue StandardError => e
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end

  def add_automation(automation)
    if automation?(automation)
      errors.add(:direction, "Automazione già attiva")
      return false
    end

    ActiveRecord::Base.transaction do
      procedures_status_automations.create!(typology: automation&.to_sym)
    end

    true
  rescue StandardError => e
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end

  def remove_automation(automation)
    unless automation?(automation)
      errors.add(:direction, "Automazione non presente")
      return false
    end

    ActiveRecord::Base.transaction do
      procedures_status_automations.find_by(typology: automation&.to_sym)&.destroy
    end

    true
  rescue StandardError => e
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end
end
