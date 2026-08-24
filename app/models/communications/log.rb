class Communications::Log < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  has_rich_text :content

  belongs_to :communication
  belongs_to :user, optional: true

  # VALIDATIONS
  ############################################################

  validate :validate_content_presence

  # SCOPES
  ############################################################

  scope :recent_first, -> { order(created_at: :desc) }

  private

  def validate_content_presence
    errors.add(:content, "non può essere vuoto") if content.blank? || content.to_plain_text.strip.blank?
  end
end
