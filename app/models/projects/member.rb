class Projects::Member < ApplicationRecord
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :role, presence: true, length: { maximum: 50 }

  # RELATIONS
  ############################################################

  belongs_to :project
  belongs_to :user

  # HOOKS
  ############################################################

  before_validation do
    self.role = capitalize_first_char(role) if role.present?
  end

  after_create :invite_member_on_slack
  after_destroy :remove_member_on_slack

  after_save :refresh_project_cache
  after_destroy :refresh_project_cache

  # OPERATIONS
  ############################################################

  def invite_member_on_slack
    return unless project.slack_channel_id

    service = SlackService.new
    slack_user_id = service.find_user_id(user.name, user.surname)
    raise unless slack_user_id

    raise unless service.invite_member_to_channel(project.slack_channel_id, slack_user_id)
  rescue StandardError => e
    Rails.logger.error e.message
    service = SlackService.new
    service.post_message_to_channel(project.slack_channel_id, "🔔 #{user.complete_name} deve essere aggiunto al canale.")
  end

  def remove_member_on_slack
    return unless project.slack_channel_id

    service = SlackService.new
    slack_user_id = service.find_user_id(user.name, user.surname)
    raise unless slack_user_id

    raise unless service.remove_member_from_channel(project.slack_channel_id, slack_user_id)
  rescue StandardError => e
    Rails.logger.error e.message
    service = SlackService.new
    service.post_message_to_channel(project.slack_channel_id, "🔔 #{user.complete_name} deve essere rimosso dal canale.")
  end

  def refresh_project_cache
    project.cached_projects_members_count(true)
  end
end
