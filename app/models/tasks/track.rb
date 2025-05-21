class Tasks::Track < ApplicationRecord
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :start_at, presence: true

  # RELATIONS
  ############################################################

  belongs_to :user, optional: true
  belongs_to :task

  # SCOPES
  ############################################################

  scope :not_closed, -> { where(end_at: nil) }
  scope :closed, -> { where.not(end_at: nil) }

  # HOOKS
  ############################################################

  before_validation on: :create do
    self.start_at = Time.now if start_at.nil? || start_at > Time.now
    self.ping_at = start_at
  end

  # cache updates
  after_save_commit do
    task.project&.cached_time_spent(true)
    task.project&.cached_percentage_budget_used(true)
  end
  after_destroy_commit do
    task.project&.cached_time_spent(true)
    task.project&.cached_percentage_budget_used(true)
  end

  # HELPERS
  ############################################################

  def duration
    return ping_at - start_at unless end_at

    end_at - start_at
  end

  # OPERATIONS
  ############################################################

  def close(with_time_limit = false)
    unless end_at.nil?
      errors.add(:base, "Track già chiuso")
      return
    end

    if with_time_limit && ping_at >= 10.minutes.ago
      errors.add(:base, "Track non ancora concluso")
      return
    end

    ActiveRecord::Base.transaction do
      time_to_close = Time.now
      if with_time_limit
        return true unless ping_at < 10.minutes.ago # do not close if last ping is too recent
        time_to_close = ping_at + 15.seconds
      end

      # set time_to_close to be at minimum 5 minutes after start_at
      time_to_close = [ time_to_close, start_at + 5.minutes ].max

      # run updates
      update!(end_at: time_to_close)
      task.update_columns(time_spent: (task.time_spent || 0) + duration)
      update_columns(time_spent: duration)
    end

    true
  rescue StandardError => e
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end
end
