class Presentations::Action < ApplicationRecord
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :page_destination, presence: true

  # RELATIONS
  ############################################################

  belongs_to :presentation
  belongs_to :presentations_page, class_name: "Presentations::Page", foreign_key: :presentations_page_id
end
