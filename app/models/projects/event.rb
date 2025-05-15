class Projects::Event < ApplicationRecord
  # VALIDATIONS
  ############################################################

  validates :message, presence: true

  # RELATIONS
  ############################################################

  belongs_to :project

  # HOOKS
  ############################################################

  # send notification on slack
  after_create do
    unless project.slack_channel_id.blank?
      service = SlackService.new
      service.post_message_to_channel(project.slack_channel_id, message)
    end
  end
end
