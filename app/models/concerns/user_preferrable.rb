module UserPreferrable
  extend ActiveSupport::Concern

  included do
    has_many :users_prefers, as: :resource, dependent: :destroy, class_name: 'Users::Prefer'

    scope :user_preferred, ->(user_id) { joins(:users_prefers).where(users_prefers: { user_id: user_id }) }
  end

  def user_prefer?(user_or_user_id)
    user_id = user_or_user_id.is_a?(User) ? user_or_user_id.id : user_or_user_id
    return @user_prefer[user_id] if @user_prefer && @user_prefer[user_id]

    user = user_or_user_id.is_a?(User) ? user_or_user_id : User.find_by(id: user_or_user_id)
    user_cached_users_prefers = user.cached_users_prefers

    @user_prefer ||= {}
    @user_prefer[user_id] ||= user_cached_users_prefers[self.class.name] && user_cached_users_prefers[self.class.name].include?(id)
  end

end