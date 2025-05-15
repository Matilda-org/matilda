class Users::Prefer < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  belongs_to :user

  belongs_to :resource, polymorphic: true

  # HOOKS
  ############################################################

  # cache updates
  after_save_commit do
    user.cached_users_prefers(true)
  end
  after_destroy_commit do
    user.cached_users_prefers(true)
  end
end
