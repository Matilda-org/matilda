class Communication < ApplicationRecord
  include Cachable

  enum :status, {
    to_send: 0,
    sent: 1,
    lost: 2,
    won: 3
  }

  # states can only move forward; to undo, delete and recreate the communication
  TRANSITIONS = {
    "to_send" => [ "sent" ],
    "sent" => [ "lost", "won" ]
  }.freeze

  # RELATIONS
  ############################################################

  belongs_to :contact
  belongs_to :campaign

  has_many :communications_logs, dependent: :destroy, class_name: "Communications::Log"

  # SCOPES
  ############################################################

  # still waiting for an outcome (not lost/won)
  scope :ongoing, -> { where(status: [ :to_send, :sent ]) }

  # VALIDATIONS
  ############################################################

  validates :contact_id, uniqueness: { scope: :campaign_id, message: "già presente nella campagna" }
  validates :sent_date, presence: true, unless: :to_send?
  validates :closed_date, presence: true, if: :closed?

  validate :validate_status_transition, on: :update

  # QUESTIONS
  ############################################################

  def closed?
    lost? || won?
  end

  # HELPERS
  ############################################################

  def status_string
    @status_string ||= Communication.status_string(status)
  end

  def status_color
    @status_color ||= Communication.status_color(status)
  end

  def status_icon
    @status_icon ||= Communication.status_icon(status)
  end

  # OPERATIONS
  ############################################################

  def mark_sent(date)
    update(status: :sent, sent_date: date)
  end

  def mark_closed(final_status, date)
    return false unless [ "lost", "won" ].include?(final_status)

    update(status: final_status, closed_date: date)
  end

  # follow-ups only make sense while waiting for an outcome
  def register_follow_up
    return false unless sent?

    increment!(:follow_ups_count)
  end

  # CLASS
  ############################################################

  def self.status_string(status)
    return "Da inviare" if status == "to_send"
    return "Inviata" if status == "sent"
    return "Perso" if status == "lost"
    return "Preso" if status == "won"

    "Non definito"
  end

  def self.status_color(status)
    return "secondary" if status == "to_send"
    return "info" if status == "sent"
    return "danger" if status == "lost"
    return "success" if status == "won"

    "secondary"
  end

  def self.status_icon(status)
    return "bi-envelope" if status == "to_send"
    return "bi-send-fill" if status == "sent"
    return "bi-x-circle-fill" if status == "lost"
    return "bi-check-circle-fill" if status == "won"

    "bi-envelope"
  end

  private

  def validate_status_transition
    return unless status_changed?

    allowed = TRANSITIONS[status_was] || []
    errors.add(:status, "non può passare da #{Communication.status_string(status_was)} a #{status_string}") unless allowed.include?(status)
  end
end
