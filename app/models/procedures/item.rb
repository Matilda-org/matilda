class Procedures::Item < ApplicationRecord
  include ActionView::RecordIdentifier
  include Cachable

  # HACK: to work on ToolsController.projects_tasks_tracking
  attr_accessor :time_spent

  # VALIDATIONS
  ############################################################

  validates :title, presence: true, length: { maximum: 200 }

  # RELATIONS
  ############################################################

  belongs_to :procedure, counter_cache: true
  belongs_to :procedures_status, class_name: "Procedures::Status", foreign_key: :procedures_status_id, counter_cache: true

  belongs_to :resource, polymorphic: true, optional: true

  # SCOPES
  ############################################################

  scope :resource_project, -> { where(resource_type: "Project") }
  scope :resource_task, -> { where(resource_type: "Task") }
  scope :search_per_project, ->(search) { joins("INNER JOIN projects ON resource_id = projects.id AND resource_type = 'Project'").where("LOWER(projects.name) LIKE :search OR LOWER(projects.code) LIKE :search", search: "%#{search.downcase}%") }
  scope :search_per_task, ->(search) { joins("INNER JOIN tasks ON resource_id = tasks.id AND resource_type = 'Task'").where("LOWER(tasks.title) LIKE :search", search: "%#{search.downcase}%") }

  # HOOKS
  ############################################################

  before_validation do
    self.procedure_id = procedures_status.procedure_id if procedure_id.nil?
    self.procedures_status_id = procedure.procedures_statuses.order(order: :asc).first.id if procedures_status_id.nil?

    if procedure.resources_type_projects? && resource_id.present?
      self.resource_type = "Project"
      self.title = "Project"
    end
    if procedure.resources_type_tasks? && resource_id.present?
      self.resource_type = "Task"
      self.title = "Task"
    end
  end

  before_create do
    default_order = (procedures_status.procedures_items.pluck(:order).max || 0) + 1
    self.order = default_order
  end

  after_create do
    # add relation to project from procedure
    if procedure.resources_type_tasks? && resource_id.present? && resource
      resource.update_columns(project_id: procedure.project_id)
      TasksRepeatManagerJob.perform_now(resource_id) if resource.repeat # HACK
    end

    # save event creation on project
    save_event_creation_on_project if procedure.resources_type_projects? && resource_id.present?

    # send update to turbo stream kanban
    create_on_turbo_stream_kanban
  end

  before_update do
    if procedure.resources_type_projects? && resource_id.present? && procedures_status_id_changed?
      save_event_change_status_on_project
    end
  end

  after_update do
    update_on_turbo_stream_kanban
  end

  after_save do
    resource&.alghoritmic_order_recalculate
  end

  after_destroy do
    if procedure.resources_type_tasks? && resource_id.present?
      resource&.destroy
    end

    destroy_on_turbo_stream_kanban
  end

  # cache updates
  after_save_commit do
    procedure.cached_project_items(true)
    procedure.cached_project_name(true)
    procedure.cached_task_items_expired_count(true)
    procedure.cached_task_items_not_completed_count(true)
    procedure.cached_task_items_completed_count(true)
  end
  after_destroy_commit do
    procedure.cached_project_items(true)
    procedure.cached_project_name(true)
    procedure.cached_task_items_expired_count(true)
    procedure.cached_task_items_not_completed_count(true)
    procedure.cached_task_items_completed_count(true)
  end

  # HELPERS
  ############################################################

  def secure_title
    begin
      return resource.title
    rescue
    end

    begin
      return resource.name
    rescue
    end

    title
  end

  def resource_color_type
    if resource && resource_type == "Task"
      return resource.color_type
    elsif resource && resource_type == "Project"
      return resource.color_type
    end

    ""
  end

  # OPERATIONS
  ############################################################

  def move(new_procedures_status_id, new_order)
    new_order = new_order.to_i

    ActiveRecord::Base.transaction do
      new_status = procedure.procedures_statuses.find(new_procedures_status_id)
      new_status_items = new_status.procedures_items.order(order: :asc).where.not(id: id)

      # update new status items order
      sum = 1
      new_status_items.each_with_index do |item, index|
        sum += 1 if index + 1 == new_order
        item.update_columns(order: index + sum)
      end

      # update item status and order (without update to avoid callback execution before automations)
      self.procedures_status_id = new_status.id
      self.order = new_order

      # manage new status automations
      new_status.procedures_status_automations.each do |automation|
        raise automation.errors.first unless automation.apply_on_item(self)
      end

      # update item to move on new status
      save!
    end

    true
  rescue StandardError => e
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end

  def save_event_creation_on_project
    resource.projects_events.create!(message: "Il progetto è entrato nella board #{procedure.name}.", data: {
      procedure_id: procedure.id
    })
  end

  def save_event_change_status_on_project
    resource.projects_events.create!(message: "Il progetto è passato in stato #{procedures_status.title} nella board #{procedure.name}.", data: {
      procedure_id: procedure.id
    })
  end

  def create_on_turbo_stream_kanban
    # update kanban status component
    update_kanban_status_component(procedures_status)
  end

  def destroy_on_turbo_stream_kanban
    # update kanban status component
    update_kanban_status_component(procedures_status)
  end

  def update_on_turbo_stream_kanban
    # update kanban status component
    update_kanban_status_component(procedures_status)
    # update old kanban status component
    if procedures_status_id_before_last_save != procedures_status_id
      procedures_status_before_last_save = procedure.procedures_statuses.find_by(id: procedures_status_id_before_last_save)
      update_kanban_status_component(procedures_status_before_last_save) if procedures_status_before_last_save
    end
  end

  private

  def update_kanban_status_component(status)
    broadcast_replace_to dom_id(status.procedure), target: dom_id(status, "kanban-status"), partial: "procedures/kanban-status", locals: { status: status }
  end
end
