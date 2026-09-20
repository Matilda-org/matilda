class Credential < ApplicationRecord
  include Cachable
  include UserPreferrable
  include Folderable

  encrypts :secure_username, :secure_password, :secure_content

  # soglie di "credenziale dimenticata": giorni dall'ultima visualizzazione
  STALE_WARNING_DAYS = 90
  STALE_URGENT_DAYS = 180

  # VALIDATIONS
  ############################################################

  validates :name, presence: true

  # SCOPES
  ############################################################

  scope :search, ->(search) { where("LOWER(name) LIKE :search", search: "%#{search.downcase}%") }
  # mai viste prima delle viste da piu tempo
  scope :least_recently_viewed, -> { order(Arel.sql("last_viewed_at IS NOT NULL, last_viewed_at ASC")) }

  # OPERATIONS
  ############################################################

  # traccia la visualizzazione senza toccare updated_at (che segna la modifica)
  def log_view!
    update_column(:last_viewed_at, Time.current)
  end

  def days_since_last_view
    return nil unless last_viewed_at

    [ (Date.today - last_viewed_at.to_date).to_i, 0 ].max
  end

  def stale_view_color
    days = days_since_last_view
    return "danger" if days.nil? || days >= STALE_URGENT_DAYS
    return "warning" if days >= STALE_WARNING_DAYS

    "secondary"
  end

  def last_view_label
    days = days_since_last_view
    return "Mai visualizzata" if days.nil?
    return "Vista oggi" if days.zero?
    return "Vista ieri" if days == 1

    "Vista #{days} giorni fa"
  end
end
