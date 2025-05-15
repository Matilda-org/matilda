class Project < ApplicationRecord
  include ActionView::RecordIdentifier
  include Cachable
  include UserPreferrable
  include Folderable
  include AlghoritmicOrderable

  enum archived_reason: {
    other: 0,
    completed: 1,
    not_started: 2,
    blocked_by_other: 3,
    blocked_by_me: 4
  }

  # RELATIONS
  ############################################################

  has_many :projects_members, dependent: :destroy, class_name: 'Projects::Member'
  has_many :projects_logs, dependent: :destroy, class_name: 'Projects::Log'
  has_many :projects_attachments, dependent: :destroy, class_name: 'Projects::Attachment'
  has_many :projects_events, dependent: :destroy, class_name: 'Projects::Event'

  has_many :procedures_items, as: :resource, dependent: :destroy, class_name: 'Procedures::Item'
  has_many :procedures_as_item, through: :procedures_items, source: :procedure

  has_many :procedures, dependent: :destroy
  has_many :tasks, dependent: :destroy

  has_many :presentations, dependent: :destroy

  # VALIDATIONS
  ############################################################

  validates :code, presence: true, length: { maximum: 50 }
  validates :name, presence: true, length: { maximum: 100 }
  validates :year, presence: true, length: { maximum: 4 }
  validates :description, length: { maximum: 255 }

  # SCOPES
  ############################################################

  scope :not_archived, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }

  scope :search, ->(search) { where('LOWER(code) LIKE :search OR LOWER(name) LIKE :search', search: "%#{search.downcase}%") }

  # HOOKS
  ############################################################

  before_validation do
    self.name = capitalize_first_char(name) if name.present?
    self.code = code.upcase if code.present?
  end

  before_validation on: :create do
    self.code = Project.default_code if code.blank?
  end

  # be sure archived projects are not in users prefer
  after_save do
    if archived
      Users::Prefer.where(
        resource_type: 'Project',
        resource_id: id
      ).destroy_all
    end
  end

  # save events
  after_save do
    if saved_change_to_name?
      projects_events.create!(
        message: "Il nome del progetto è stato modificato in \"#{name}\"."
      )
    end

    if saved_change_to_archived?
      projects_events.create!(
        message: "Il progetto è stato #{archived ? 'archiviato' : 'riattivato'}."
      )
    end
  end

  # cache updates
  after_save_commit do
    tasks.each do |task|
      task.cached_project_name(true)
    end
    procedures.each do |procedure|
      procedure.cached_project_name(true)
    end
    procedures_as_item.each do |procedure|
      procedure.cached_project_items(true)
    end
  end
  after_destroy_commit do
    procedures.each do |procedure|
      procedure.cached_project_name(true)
    end
    procedures_as_item.each do |procedure|
      procedure.cached_project_items(true)
    end
  end

  # slack sync
  before_update :update_name_on_slack, if: :name_changed?
  before_update :archive_on_slack, if: :archived_changed?
  before_update :unarchive_on_slack, if: :archived_changed?
  after_destroy :destroy_on_slack

  # QUESTIONS
  ############################################################

  def member_exists?(user_id)
    projects_members.where(user_id: user_id).exists?
  end

  # HELPERS
  ############################################################

  def name_2chars
    name_2chars = name.gsub(/[^a-zA-Z]/, '')[0..1].upcase
    name_2chars = name_2chars[0] + 'X' if name_2chars.length < 2

    name_2chars
  end

  def complete_code
    [year, code].join(' - ')
  end

  def description_with_budget
    return description unless budget_management

    budget = "💰 #{budget_money}€ ⏱️ #{track_time_string(budget_time)} 📊 #{budget_money_per_time}€/h"

    "#{budget}\n\n#{description}"
  end

  def complete_code_name
    [year, code, name].join(' - ')
  end

  def procedures_valid
    @procedures_valid ||= Procedure.valid_for_projects
  end

  def procedures_valid_as_item
    @procedures_valid_as_item ||= Procedure.valid_for_projects_items.where.not(id: procedures_as_item.pluck(:id))
  end

  def archived_reason_string
    @archived_reason_string ||= Project.archived_reason_string(archived_reason)
  end

  def budget_money_per_time
    return 0 unless budget_management
    return 0 if budget_time.zero?

    (budget_money.to_f / budget_time.to_f * 3600).round(2)
  end

  def color_type
    type = ''
    type = 'dark' if archived

    type
  end

  def cached_projects_members_count(reset = false)
    Rails.cache.delete("Project/cached_projects_members_count/#{id}") if reset

    @cached_projects_members_count ||= Rails.cache.fetch("Project/cached_projects_members_count/#{id}", expires_in: 7.days) do
      projects_members.count
    end
  end

  def cached_time_spent(reset = false)
    Rails.cache.delete("Project/cached_time_spent/#{id}") if reset

    @cached_time_spent ||= Rails.cache.fetch("Project/cached_time_spent/#{id}", expires_in: 7.days) do
      tasks.sum(:time_spent)
    end
  end

  def cached_percentage_budget_used(reset = false)
    Rails.cache.delete("Project/cached_percentage_budget_used/#{id}") if reset

    @cached_percentage_budget_used ||= Rails.cache.fetch("Project/cached_percentage_budget_used/#{id}", expires_in: 7.days) do
      return 0 unless budget_management
      return 100 if budget_time.zero?

      tasks_time_spent = tasks.sum(:time_spent)
      return 0 if tasks_time_spent.zero?

      (tasks_time_spent.to_f / budget_time.to_f * 100).round(2)
    end
  end

  def track_time_string(seconds) # From ApplicationHelper.track_time
    seconds_diff = seconds
    hours = seconds_diff / 3600
    seconds_diff -= hours * 3600
    minutes = seconds_diff / 60

    "#{hours.to_s.rjust(2, '0')}h #{minutes.to_s.rjust(2, '0')}m"
  end

  # OPERATIONS
  ############################################################

  def create_on_slack
    service = SlackService.new
    response = service.create_channel(name)
    return unless response

    update_column(:slack_channel_id, response['id'])
  end

  def update_name_on_slack
    return unless slack_channel_id

    service = SlackService.new
    service.rename_channel(slack_channel_id, name)
  end

  def archive_on_slack
    return unless slack_channel_id
    return unless archived

    service = SlackService.new
    service.rename_channel(slack_channel_id, "_archived_#{name}")
  end

  def unarchive_on_slack
    return unless slack_channel_id
    return if archived

    service = SlackService.new
    service.rename_channel(slack_channel_id, name)
  end

  def destroy_on_slack
    return unless slack_channel_id

    service = SlackService.new
    service.rename_channel(slack_channel_id, "_deleted_#{name}")
    service.archive_channel(slack_channel_id)
  end

  # CLASS
  ############################################################

  def self.archived_reason_string(archived_reason)
    return 'Altro' if archived_reason == 'other'
    return 'Completato' if archived_reason == 'completed'
    return 'Non iniziato' if archived_reason == 'not_started'
    return 'Bloccato da cliente' if archived_reason == 'blocked_by_other'
    return 'Bloccato da azienda' if archived_reason == 'blocked_by_me'

    'Non definito'
  end

  def self.default_code
    SecureRandom.hex(3).upcase
  end
end
