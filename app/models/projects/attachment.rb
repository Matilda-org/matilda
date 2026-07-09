class Projects::Attachment < ApplicationRecord
  include Cachable

  enum :typology, {
    general: 0,
    quotation_delivered: 1,
    quotation_accepted: 2,
    presentation: 3,
    client_content: 4
  }

  # VALIDATIONS
  ############################################################

  validates :title, presence: true
  validates :date, presence: true
  validate :file_validation

  # RELATIONS
  ############################################################

  belongs_to :project

  has_one_attached :file

  # HOOKS
  ############################################################

  after_create :save_event_creation_on_project

  # HELPERS
  ############################################################

  def typology_string
    @typology_string ||= Projects::Attachment.typology_string(typology)
  end

  # Bootstrap color used for the typology badge.
  def typology_color
    Projects::Attachment.typology_color(typology)
  end

  # Bootstrap Icons class for the attached file, based on its content type.
  def file_icon
    return "bi-paperclip" unless file.attached?

    case file.content_type
    when "application/pdf" then "bi-file-earmark-pdf"
    when "image/jpeg", "image/png" then "bi-file-earmark-image"
    when "text/plain" then "bi-file-earmark-text"
    when "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then "bi-file-earmark-word"
    when "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" then "bi-file-earmark-spreadsheet"
    else "bi-file-earmark"
    end
  end

  # Bootstrap text color paired with #file_icon.
  def file_icon_color
    return "secondary" unless file.attached?

    case file.content_type
    when "application/pdf" then "danger"
    when "image/jpeg", "image/png" then "info"
    when "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then "primary"
    when "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" then "success"
    else "secondary"
    end
  end

  # OPERATIONS
  ############################################################

  def save_event_creation_on_project
    project.projects_events.create!(message: "Allegato #{title} (versione #{version}) - caricato su Matilda.", data: {
      attachment_id: id
    })
  end

  private

  def file_validation
    return true unless file.attached?

    allowed_content_types = %w[
      application/pdf
      image/jpeg
      image/png
      text/plain
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/vnd.ms-excel
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    ]

    errors.add(:file, "non supportato") unless file.content_type.in?(allowed_content_types)
    errors.add(:file, "troppo grande") if file.byte_size > 25.megabytes
  end

  # CLASS
  ############################################################

  def self.typology_string(typology)
    return "Altro" if typology == "general"
    return "Preventivo inviato" if typology == "quotation_delivered"
    return "Preventivo firmato" if typology == "quotation_accepted"
    return "Presentazione progetto" if typology == "presentation"
    return "Materiale cliente" if typology == "client_content"

    "Non definito"
  end

  def self.typology_color(typology)
    {
      "general" => "secondary",
      "quotation_delivered" => "info",
      "quotation_accepted" => "success",
      "presentation" => "primary",
      "client_content" => "warning"
    }[typology] || "secondary"
  end
end
