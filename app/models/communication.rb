class Communication < ApplicationRecord
  include Cachable

  enum :status, {
    to_send: 0,
    sent: 1,
    lost: 2,
    won: 3
  }

  # giorni di silenzio dopo i quali la comunicazione va sollecitata o chiusa
  SILENCE_WARNING_DAYS = 7
  SILENCE_URGENT_DAYS = 21

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
  has_many :communications_follow_ups, dependent: :destroy, class_name: "Communications::FollowUp"

  # SCOPES
  ############################################################

  # still waiting for an outcome (not lost/won)
  scope :ongoing, -> { where(status: [ :to_send, :sent ]) }

  # each column of the board reads in the order that matters for it: the oldest
  # queued or waiting first (they need attention), the latest outcomes on top
  scope :board_order, ->(status) {
    return order(created_at: :asc) if status == "to_send"
    return order(sent_date: :asc, created_at: :asc) if status == "sent"

    order(closed_date: :desc, updated_at: :desc)
  }

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

  # giorni di attesa dell'esito: contano dall'invio
  def days_waiting
    return nil unless sent? && sent_date

    (Date.today - sent_date).to_i
  end

  # ultima volta che ci si è mossi: l'invio, oppure il follow-up più recente
  def last_activity_date
    return nil unless sent? && sent_date

    [ sent_date, communications_follow_ups.maximum(:date) ].compact.max
  end

  # silenzio dall'ultima mossa: è questo, non la data d'invio, che dice se è
  # il momento di sollecitare (un follow-up di ieri azzera l'urgenza)
  def days_since_last_activity
    date = last_activity_date
    return nil unless date

    # un follow-up datato nel futuro non produce silenzio negativo
    [ (Date.today - date).to_i, 0 ].max
  end

  def days_waiting_color
    days = days_since_last_activity
    return "secondary" if days.nil?
    return "danger" if days >= SILENCE_URGENT_DAYS
    return "warning" if days >= SILENCE_WARNING_DAYS

    "info"
  end

  # da sollecitare o da chiudere: silenzio oltre la soglia
  def needs_attention?
    days = days_since_last_activity

    days.present? && days >= SILENCE_WARNING_DAYS
  end

  def status_color
    @status_color ||= Communication.status_color(status)
  end

  def status_icon
    @status_icon ||= Communication.status_icon(status)
  end

  # OPERATIONS
  ############################################################

  # confirmed dates are never rewritten: each step runs once, from its own state
  def mark_sent(date)
    unless to_send?
      errors.add(:status, "la comunicazione è già stata inviata")
      return false
    end

    update(status: :sent, sent_date: date)
  end

  def mark_closed(final_status, date)
    unless [ "lost", "won" ].include?(final_status)
      errors.add(:status, "esito non valido: usa perso o preso")
      return false
    end
    unless sent?
      errors.add(:status, "l'esito si registra solo su comunicazioni inviate")
      return false
    end

    update(status: final_status, closed_date: date)
  end

  # follow-ups only make sense while waiting for an outcome; each one is a dated
  # record, so it can be listed and undone (follow_ups_count is its counter cache)
  def register_follow_up(date = Date.today, user = nil)
    unless sent?
      errors.add(:base, "i follow-up si registrano solo su comunicazioni inviate")
      return false
    end

    follow_up = communications_follow_ups.new(date: date.presence || Date.today, user: user)
    return follow_up if follow_up.save

    errors.add(:base, follow_up.errors.full_messages.to_sentence)
    false
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
