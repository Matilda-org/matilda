class Tasks::Follower < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  belongs_to :user, optional: true
  belongs_to :task
end
