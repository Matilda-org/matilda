class Notification < ApplicationRecord
  enum typology: {
    general: 0,
    task_assigned: 1,
  }

  # RELATIONS
  ############################################################
  
  belongs_to :user
end
