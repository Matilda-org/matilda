class Procedure < ApplicationRecord
  include Cachable
  include UserPreferrable

  # HACK: to work on ToolsController.projects_tasks_tracking
  attr_accessor :time_spent

  enum resources_type: {
    projects: 1,
    tasks: 2
  }

  # RELATIONS
  ############################################################

  has_many :procedures_statuses, dependent: :destroy, class_name: "Procedures::Status"

  has_many :procedures_items, dependent: :destroy, class_name: "Procedures::Item"
  has_many :projects_items, through: :procedures_items, source: :resource, source_type: "Project", class_name: "Project"
  has_many :tasks_items, through: :procedures_items, source: :resource, source_type: "Task", class_name: "Task"

  belongs_to :project, optional: true

  # VALIDATIONS
  ############################################################

  validates :name, presence: true, length: { maximum: 50 }
  validates :description, length: { maximum: 255 }

  # SCOPES
  ############################################################

  scope :not_archived, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }
  scope :not_as_model, -> { where(model: false) }
  scope :as_model, -> { where(model: true) }

  scope :resources_type_projects, -> { where(resources_type: "projects") }
  scope :resources_type_tasks, -> { where(resources_type: "tasks") }

  scope :search, ->(search) { left_joins(:project).where("LOWER(procedures.name) LIKE :search OR LOWER(projects.code) LIKE :search OR LOWER(projects.name) LIKE :search", search: "%#{search.downcase}%") }

  # ritorna le board che possono essere usate per creare board interni di progetto
  scope :valid_for_projects, -> { not_archived.as_model.where(resources_type: "tasks") }
  # ritorna le board che possono essere usate per creare board esterni di progetto
  scope :valid_for_projects_items, -> { not_archived.not_as_model.resources_type_projects.where("statuses_count > 0") }

  # HOOKS
  ############################################################

  before_validation do
    self.name = capitalize_first_char(name) if name.present?
  end

  # be sure archived procedures are not in users prefer
  after_save do
    if archived
      Users::Prefer.where(
        resource_type: "Procedure",
        resource_id: id
      ).destroy_all
    end
  end

  # QUESTIONS
  ############################################################

  def resources_type_projects?
    resources_type == "projects"
  end

  def resources_type_tasks?
    resources_type == "tasks"
  end

  def archivable?
    !model
  end

  def clonable?
    project_id.nil?
  end

  # HELPERS
  ############################################################

  def resources_type_string
    @resources_type_string ||= Procedure.resources_type_string(resources_type)
  end

  def resources_items_string
    @resources_items_string ||= Procedure.resources_items_string(resources_type)
  end

  def resources_item_string
    @resources_item_string ||= Procedure.resources_item_string(resources_type)
  end

  def color_type
    type = ""
    type = "secondary" if model
    type = "dark" if archived
    type = "light" if resources_type_projects?

    type
  end

  def cached_project_items(reset = false)
    Rails.cache.delete("Procedure/cached_project_items/#{id}") if reset

    @cached_project_items ||= Rails.cache.fetch("Procedure/cached_project_items/#{id}", expires_in: 7.days) do
      projects_items.order(:name).map do |project|
        {
          id: project.id,
          name: project.name
        }
      end
    end
  end

  def cached_project_name(reset = false)
    Rails.cache.delete("Procedure/cached_project_name/#{id}") if reset

    return "" unless project_id

    @cached_project_name ||= Rails.cache.fetch("Procedure/cached_project_name/#{id}", expires_in: 7.days) do
      project.name
    end
  end

  def cached_task_items_expired_count(reset = false)
    Rails.cache.delete("Procedure/cached_task_items_expired_count/#{id}") if reset

    @cached_task_items_expired_count ||= Rails.cache.fetch("Procedure/cached_task_items_expired_count/#{id}", expires_in: 7.days) do
      tasks_items.not_completed.expired.count
    end
  end

  def cached_task_items_not_completed_count(reset = false)
    Rails.cache.delete("Procedure/cached_task_items_not_completed_count/#{id}") if reset

    @cached_task_items_not_completed_count ||= Rails.cache.fetch("Procedure/cached_task_items_not_completed_count/#{id}", expires_in: 7.days) do
      tasks_items.not_completed.not_expired.count
    end
  end

  def cached_task_items_completed_count(reset = false)
    Rails.cache.delete("Procedure/cached_task_items_completed_count/#{id}") if reset

    @cached_task_items_completed_count ||= Rails.cache.fetch("Procedure/cached_task_items_completed_count/#{id}", expires_in: 7.days) do
      tasks_items.completed.count
    end
  end

  # OPERATIONS
  ############################################################

  def clone(procedure_to_clone, new_name = nil, tasks_data = {})
    ActiveRecord::Base.transaction do
      self.name = new_name || "#{procedure_to_clone.name} (clone)"
      self.resources_type = procedure_to_clone.resources_type
      self.archived = false
      self.model = false
      self.items_count = 0
      self.statuses_count = 0
      save!

      # copy each status of the procedure
      procedure_to_clone.procedures_statuses.each do |status|
        new_status = status.dup
        new_status.procedure = self
        new_status.items_count = 0
        new_status.save!
        new_status.update_column(:order, status.order)

        # copy each automation of the status
        status.procedures_status_automations.each do |automation|
          new_automation = automation.dup
          new_automation.procedures_status = new_status
          new_automation.save!
        end

        # copy each item of the status
        status.procedures_items.each do |item|
          if procedure_to_clone.model && procedure_to_clone.resources_type_projects?
            next
          elsif !procedure_to_clone.model && procedure_to_clone.resources_type_tasks?
            next
          else
            new_item = item.dup
            new_item.procedures_status = new_status
            new_item.procedure = self
            new_item.model_data = nil
            if procedure_to_clone.model && procedure_to_clone.resources_type_tasks?
              p = item.model_data
              tasks_data.each do |k, v|
                next if v.blank?
                p[k] = v
              end
              new_item.resource_id = Task.create(p)&.id
            end

            new_item.save!
          end
        end
      end
    end

    true
  rescue StandardError => e
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end

  # CLASS
  ############################################################

  def self.resources_type_string(resources_type)
    return "Progetti" if resources_type == "projects"
    return "Task" if resources_type == "tasks"

    "Non definito"
  end

  def self.resources_items_string(resources_type)
    return "progetti" if resources_type == "projects"
    return "task" if resources_type == "tasks"

    "elementi"
  end

  def self.resources_item_string(resources_type)
    return "progetto" if resources_type == "projects"
    return "task" if resources_type == "tasks"

    "elemento"
  end
end
