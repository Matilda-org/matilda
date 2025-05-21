class Projects::Log < ApplicationRecord
  include ActionView::RecordIdentifier
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :title, presence: true, length: { maximum: 255 }
  validates :date, presence: true

  # RELATIONS
  ############################################################

  has_rich_text :content

  belongs_to :project
  belongs_to :user, optional: true

  # HOOKS
  ############################################################

  before_validation do
    self.title = capitalize_first_char(title) if title.present?
  end

  after_create :save_event_creation_on_project
  after_update :update_on_turbo_stream_content

  # OPERATIONS
  ############################################################

  def save_event_creation_on_project
    project.projects_events.create!(message: "#{user&.complete_name || 'Qualcuno'} ha caricato la nota #{title} del #{date.strftime('%d/%m/%Y')} su Matilda.", data: {
      log_id: id,
      user_id: user_id
    })
  end

  def update_on_turbo_stream_content
    broadcast_replace_to dom_id(self), target: dom_id(self, "content"), partial: "projects/shared/log-content", locals: { log: self }
  end

  # HELPERS
  ############################################################

  def shareable?
    share_code.present?
  end
end
