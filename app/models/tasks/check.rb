class Tasks::Check < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  belongs_to :task

  # HOOKS
  ############################################################

  before_create do
    default_order = (task.tasks_checks.pluck(:order).max || 0) + 1
    self.order = default_order
  end
end
