class Projects::Attachment < ApplicationRecord
  include Cachable

  enum typology: {
    general: 0,
    quotation_delivered: 1,
    quotation_accepted: 2,
    presentation: 3,
    client_content: 4,
  }

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

  # OPERATIONS
  ############################################################

  def save_event_creation_on_project
    project.projects_events.create!(message: "Allegato #{title} (versione #{version}) - caricato su Matilda.", data: {
      attachment_id: id
    })
  end

  # CLASS
  ############################################################

  def self.typology_string(typology)
    return 'Altro' if typology == 'general'
    return 'Preventivo inviato' if typology == 'quotation_delivered'
    return 'Preventivo firmato' if typology == 'quotation_accepted'
    return 'Presentazione progetto' if typology == 'presentation'
    return 'Materiale cliente' if typology == 'client_content'

    'Non definito'
  end
end
