class Campaign < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  has_many :communications, dependent: :destroy
  has_many :contacts, through: :communications

  # VALIDATIONS
  ############################################################

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 255 }

  # SCOPES
  ############################################################

  scope :not_archived, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }

  scope :search, ->(search) { where("LOWER(name) LIKE :search", search: "%#{search.downcase}%") }

  # HOOKS
  ############################################################

  before_validation do
    self.name = capitalize_first_char(name) if name.present?
  end

  # HELPERS
  ############################################################

  def color_type
    type = ""
    type = "dark" if archived

    type
  end

  # {"to_send" => n, "sent" => n, "lost" => n, "won" => n}
  def communications_counts
    @communications_counts ||= communications.group(:status).count
  end

  # active contacts without a communication in this campaign yet
  def contacts_available
    Contact.not_archived.where.not(id: communications.select(:contact_id)).order(name: :asc)
  end
end
