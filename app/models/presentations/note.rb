class Presentations::Note < ApplicationRecord
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :content, presence: true, length: { maximum: 999 }

  # RELATIONS
  ############################################################

  belongs_to :presentation
  belongs_to :presentations_page, class_name: 'Presentations::Page', foreign_key: :presentations_page_id
end
