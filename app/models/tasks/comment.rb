class Tasks::Comment < ApplicationRecord
  # VALIDATIONS
  ############################################################

  validates :content, presence: true

  # RELATIONS
  ############################################################

  belongs_to :user, optional: true
  belongs_to :task
end
