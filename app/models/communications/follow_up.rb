class Communications::FollowUp < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  belongs_to :communication, counter_cache: :follow_ups_count
  belongs_to :user, optional: true

  # VALIDATIONS
  ############################################################

  validates :date, presence: true

  # SCOPES
  ############################################################

  scope :recent_first, -> { order(date: :desc, created_at: :desc) }
end
