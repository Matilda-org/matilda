class Task < ApplicationRecord
  include ActionView::Helpers::DateHelper
  include ActionView::RecordIdentifier
  include Cachable
  include AlghoritmicOrderable

  attr_accessor :description # retro-compatibilità sostituzione description con content
  attr_accessor :tasks_followers_user_ids
  attr_accessor :tasks_checks_texts
  attr_accessor :position_procedure_id

  enum repeat_type: { weekly: 0, monthly: 1 }, _prefix: true
  enum repeat_monthday: { first: 0, last: 1, middle: 2 }, _prefix: true

  # VALIDATIONS
  ############################################################

  validates :title, presence: true, length: { maximum: 200 }

  # SCOPES
  ############################################################

  scope :today, -> { where("deadline = ?", Date.today) }
  scope :expired, -> { where("deadline < ?", Date.today) }
  scope :not_expired, -> { where("deadline >= ?", Date.today) }
  scope :not_completed, -> { where(completed: false) }
  scope :completed, -> { where(completed: true) }

  scope :search, ->(search) { where("LOWER(title) LIKE :search", search: "%#{search.downcase}%") }

  # RELATIONS
  ############################################################

  has_rich_text :content

  belongs_to :user, optional: true
  belongs_to :project, optional: true

  has_many :procedures_items, as: :resource, dependent: :destroy, class_name: "Procedures::Item"
  has_many :procedures_as_item, through: :procedures_items, source: :procedure

  has_many :tasks_tracks, dependent: :destroy, class_name: "Tasks::Track"
  has_many :tasks_followers, dependent: :destroy, class_name: "Tasks::Follower"
  has_many :tasks_checks, dependent: :destroy, class_name: "Tasks::Check"

  # HOOKS
  ############################################################

  before_save do
    if self.repeat && self.repeat_from.blank?
      errors.add(:repeat_from, "è obbligatorio se si vuole ripetere il task")
      throw(:abort)
    end

    if self.repeat && self.repeat_to.blank?
      errors.add(:repeat_to, "è obbligatorio se si vuole ripetere il task")
      throw(:abort)
    end

    self.repeat_weekdays = repeat_weekdays.reject(&:blank?).map(&:to_i) if repeat_weekdays
    self.time_estimate ||= 0
    self.time_spent ||= 0
  end

  after_create do
    if !position_procedure_id.blank? && position_procedure_id != procedure_as_item&.id
      procedures_items.where.not(procedure_id: position_procedure_id).destroy_all
      procedures_items.find_or_create_by(procedure_id: position_procedure_id)
    end
  end

  # create followers
  after_save do
    if tasks_followers_user_ids
      tasks_followers_user_ids_valid = tasks_followers_user_ids.reject(&:blank?)
      tasks_followers_user_ids_valid.delete(user_id) if user_id

      tasks_followers_user_ids_valid.each do |user_id|
        tasks_followers.find_or_create_by!(user_id: user_id)
      end

      tasks_followers.where.not(user_id: tasks_followers_user_ids_valid).destroy_all
    end

    if user_id && !tasks_followers.where(user_id: user_id).empty?
      tasks_followers.where(user_id: user_id).destroy_all
    end

    # force creation of followers for users with tasks_acceptance policy when task is not accepted
    if !accepted
      users_with_tasks_acceptance_policy = User.joins(:users_policies).where(users_policies: { policy: :tasks_acceptance })
      users_with_tasks_acceptance_policy.each do |user|
        tasks_followers.find_or_create_by!(user_id: user.id)
      end
    end
  end

  # create checks
  after_save do
    if tasks_checks_texts
      tasks_checks_texts_valid = tasks_checks_texts.reject(&:blank?)&.uniq
      tasks_checks_texts_valid.each do |text|
        tasks_checks.find_or_create_by!(text: text)
      end

      tasks_checks.where.not(text: tasks_checks_texts_valid).destroy_all
    end
  end

  after_save do
    Rails.cache.delete("Task/#{id}/description")
  end

  # procedure automation :take_completed_task
  after_save do
    if saved_change_to_completed? && completed
      procedures_as_item.each do |procedure|
        procedure.procedures_statuses.each do |status|
          next unless status.procedures_status_automations.find_by(typology: :take_completed_task)

          item = procedures_items.find_by(procedure_id: procedure.id)
          next unless item

          item.move(status.id, status.procedures_items.count + 1)
        end
      end
    end
  end

  # cache updates
  after_save_commit do
    project&.cached_time_spent(true)
    project&.cached_percentage_budget_used(true)
    cached_project_name(true)

    procedures_as_item.each do |procedure|
      procedure.cached_task_items_expired_count(true)
      procedure.cached_task_items_not_completed_count(true)
      procedure.cached_task_items_completed_count(true)
    end
  end
  after_destroy_commit do
    project&.cached_time_spent(true)
    project&.cached_percentage_budget_used(true)
    procedures_as_item.each do |procedure|
      procedure.cached_task_items_expired_count(true)
      procedure.cached_task_items_not_completed_count(true)
      procedure.cached_task_items_completed_count(true)
    end
  end

  # repeat manager
  after_create_commit do
    TasksRepeatManagerJob.perform_now(id) if repeat
  end
  after_update_commit do
    TasksRepeatManagerJob.perform_now
  end
  after_destroy_commit do
    TasksRepeatManagerJob.perform_now
  end

  # turbo stream updates
  after_save_commit do
    if user_id
      broadcast_replace_to dom_id(user), target: dom_id(user, "stats"), partial: "users/stats", locals: { user: user }
    end
  end

  # notifications
  after_save_commit do
    if saved_change_to_user_id? && user_id
      Notification.create(user_id: user_id, typology: :task_assigned, data: { task_id: id })
    end
  end

  # QUESTIONS
  ############################################################

  def expired?
    deadline&.past?
  end

  def today?
    deadline == Date.today
  end

  # HELPERS
  ############################################################

  def subtitle
    completed ? completed_at_in_words : deadline_in_words
  end

  def tasks_followers_user_ids
    @tasks_followers_user_ids ||= tasks_followers.pluck(:user_id)
  end

  def tasks_checks_texts
    @tasks_checks_texts ||= tasks_checks.order(order: :asc).pluck(:text)
  end

  def description
    Rails.cache.fetch("Task/#{id}/description", expires_in: 7.days) do
      content.to_plain_text.truncate(100)
    end
  end

  def open_tasks_track_for_user(user_id)
    tasks_tracks.not_closed.where(user_id: user_id).order(start_at: :desc).first
  end

  def procedure_as_item
    @procedure_as_item ||= procedures_as_item.first
  end

  def deadline_in_words
    return "Nessuna scadenza" unless deadline

    if deadline.to_date == Date.today
      "Scade oggi"
    else
      prefix = deadline.past? ? "Scaduta da" : "Scade tra"
      "#{prefix} #{distance_of_time_in_words_to_now(deadline.at_end_of_day)}"
    end
  end

  def completed_at_in_words
    return "Completato" unless completed_at

    "Completato il #{completed_at.strftime('%d/%m/%Y')}"
  end

  def time_alert
    return false unless time_spent && time_estimate

    time_spent > time_estimate
  end

  def color_type
    type = "secondary"
    type = "info" if deadline
    type = "danger" if expired?
    type = "warning" if today?
    type = "success" if completed
    type = "secondary" if !accepted

    type
  end

  def cached_project_name(reset = false)
    Rails.cache.delete("Task/#{id}/cached_project_name") if reset

    return "" unless project_id

    @cached_project_name ||= Rails.cache.fetch("Task/#{id}/cached_project_name", expires_in: 7.days) do
      project&.name
    end
  end

  def time_spent_as_string # From ApplicationHelper.track_time
    seconds_diff = time_spent
    hours = seconds_diff / 3600
    seconds_diff -= hours * 3600
    minutes = seconds_diff / 60

    "#{hours.to_s.rjust(2, '0')}h #{minutes.to_s.rjust(2, '0')}m"
  end

  def time_estimate_as_string # From ApplicationHelper.track_time
    seconds_diff = time_estimate
    hours = seconds_diff / 3600
    seconds_diff -= hours * 3600
    minutes = seconds_diff / 60

    "#{hours.to_s.rjust(2, '0')}h #{minutes.to_s.rjust(2, '0')}m"
  end
end
