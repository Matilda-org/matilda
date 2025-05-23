class Credential < ApplicationRecord
  include Cachable
  include UserPreferrable
  include Folderable

  encrypts :secure_username, :secure_password, :secure_content

  # SCOPES
  ############################################################

  scope :search, ->(search) { where("LOWER(name) LIKE :search", search: "%#{search.downcase}%") }
end
