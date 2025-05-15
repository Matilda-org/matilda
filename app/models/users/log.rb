class Users::Log < ApplicationRecord
  include Cachable

  enum typology: {
    unknown: 0,
    search: 1,
    credential: 2,
  }

  # RELATIONS
  ############################################################

  belongs_to :user

  # SCOPES
  ############################################################

  scope :search, -> { where(typology: :search) }
  scope :credential, -> { where(typology: :credential) }
end
