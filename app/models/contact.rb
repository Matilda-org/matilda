class Contact < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  has_many :communications, dependent: :destroy
  has_many :campaigns, through: :communications

  has_many :projects, dependent: :nullify

  # VALIDATIONS
  ############################################################

  validates :name, presence: true, length: { maximum: 100 }
  validates :vat_number, length: { maximum: 50 }
  validates :email, length: { maximum: 100 }
  validates :phone, length: { maximum: 50 }
  validates :website, length: { maximum: 255 }
  validates :address, length: { maximum: 255 }
  validates :description, length: { maximum: 255 }

  # SCOPES
  ############################################################

  scope :not_archived, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }

  scope :search, ->(search) { where("LOWER(name) LIKE :search OR LOWER(email) LIKE :search", search: "%#{search.downcase}%") }

  # HOOKS
  ############################################################

  before_validation do
    self.name = capitalize_first_char(name) if name.present?
  end

  # HELPERS
  ############################################################

  def name_2chars
    name_2chars = name.gsub(/[^a-zA-Z]/, "")[0..1].upcase
    name_2chars = name_2chars[0] + "X" if name_2chars.length < 2

    name_2chars
  end

  def color_type
    type = ""
    type = "dark" if archived

    type
  end

  # cache updates
  after_save_commit do
    projects.each { |project| project.cached_contact_name(true) } if saved_change_to_name?
  end
  # snapshot before dependent: :nullify clears the association
  before_destroy do
    @projects_to_refresh = projects.to_a
  end
  after_destroy_commit do
    (@projects_to_refresh || []).each { |project| project.cached_contact_name(true) }
  end
end
