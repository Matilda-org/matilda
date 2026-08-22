class Communications::Log < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  belongs_to :communication
  belongs_to :user, optional: true

  # VALIDATIONS
  ############################################################

  validates :content, presence: true, length: { maximum: 1000 }

  # SCOPES
  ############################################################

  scope :recent_first, -> { order(created_at: :desc) }
end
