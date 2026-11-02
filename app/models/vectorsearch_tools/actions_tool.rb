# Write tools of the chat assistant. Calling them writes nothing: each call
# stores a proposal and the user runs it with the "Conferma" button
# (Vectorsearch#confirm_action), which needs no AI call. The chat can also read
# web pages, so without the confirmation an instruction hidden in a page could
# act with the user's permissions.
class VectorsearchTools::ActionsTool
  include VectorsearchTools::Definition
  include VectorsearchTools::Access

  ACTIONS = %w[projects_create projects_update projects_duplicate tasks_create tasks_complete tasks_comment crm_communication_log_create crm_follow_up_create].freeze
  PROPOSAL_TTL = 1.day
  PROJECT_FIELDS = %i[name year code description contact_id].freeze

  # proposals stored during this run, shown as buttons under the answer
  attr_reader :proposals

  def initialize(user)
    @user = user
    @proposals = []
  end

  # Runs a confirmed proposal. Checks run again: permissions or data may have
  # changed since the proposal.
  def execute(type, data)
    return "Azione non valida" unless ACTIONS.include?(type.to_s)

    error = send("check_#{type}", data)
    return error if error

    send("perform_#{type}", data)
  end

  # Projects
  ##

  define_function :projects_create, description: "Propose a new project, the user confirms it. To start from an existing project use projects_duplicate" do
    property :name, type: "string", description: "Project name", required: true
    property :year, type: "integer", description: "Project year", required: true
    property :code, type: "string", description: "Project code (generated when missing)", required: false
    property :description, type: "string", description: "Project description (max 255 characters)", required: false
    property :contact_id, type: "integer", description: "CRM contact ID of the customer", required: false
  end

  def projects_create(data)
    propose(:projects_create, data)
  end

  define_function :projects_update, description: "Propose changes to a project, only the given fields change, the user confirms it" do
    property :project_id, type: "integer", description: "Project ID", required: true
    property :name, type: "string", description: "New project name", required: false
    property :year, type: "integer", description: "New project year", required: false
    property :code, type: "string", description: "New project code", required: false
    property :description, type: "string", description: "New project description (max 255 characters)", required: false
    property :contact_id, type: "integer", description: "New CRM contact ID", required: false
  end

  def projects_update(data)
    propose(:projects_update, data)
  end

  define_function :projects_duplicate, description: "Propose a new project similar to an existing one: same contact, folder and members, and a new empty copy of each of its boards (same columns, no tasks). The user confirms it" do
    property :source_project_id, type: "integer", description: "ID of the project to copy", required: true
    property :name, type: "string", description: "New project name", required: true
    property :year, type: "integer", description: "New project year (default: the source one)", required: false
    property :code, type: "string", description: "New project code (generated when missing)", required: false
    property :description, type: "string", description: "New project description (default: the source one)", required: false
  end

  def projects_duplicate(data)
    propose(:projects_duplicate, data)
  end

  # Tasks
  ##

  define_function :tasks_create, description: "Propose a new task (use task also for reminder, to-dos ecc.), the user confirms it" do
    property :user_id, type: "integer", description: "Assignee user ID", required: true
    property :title, type: "string", description: "Task title", required: true
    property :deadline, type: "string", description: "Task deadline (YYYY-MM-DD)", required: false
    property :checklist, type: "string", description: "Task checklist items (JSON array of strings)", required: false
    property :procedure_id, type: "integer", description: "Board ID where the task should be created (require also procedure_status_id)", required: false
    property :procedure_status_id, type: "integer", description: "Board status ID where the task should be created", required: false
  end

  def tasks_create(data)
    propose(:tasks_create, data)
  end

  define_function :tasks_complete, description: "Propose to mark a task as completed, the user confirms it" do
    property :task_id, type: "integer", description: "Task ID", required: true
  end

  def tasks_complete(data)
    propose(:tasks_complete, data)
  end

  define_function :tasks_comment, description: "Propose a comment on a task, the user confirms it" do
    property :task_id, type: "integer", description: "Task ID", required: true
    property :content, type: "string", description: "Comment text (markdown)", required: true
  end

  def tasks_comment(data)
    propose(:tasks_comment, data)
  end

  # CRM
  ##

  define_function :crm_communication_log_create, description: "Propose a note on a CRM communication, the user confirms it" do
    property :communication_id, type: "integer", description: "Communication ID", required: true
    property :content, type: "string", description: "Note text", required: true
  end

  def crm_communication_log_create(data)
    propose(:crm_communication_log_create, data)
  end

  define_function :crm_follow_up_create, description: "Propose to register a follow-up (reminder sent today) on a sent CRM communication, the user confirms it" do
    property :communication_id, type: "integer", description: "Communication ID", required: true
  end

  def crm_follow_up_create(data)
    propose(:crm_follow_up_create, data)
  end

  private

  def propose(type, data)
    error = send("check_#{type}", data)
    return error if error

    id = SecureRandom.hex(8)
    label = send("label_#{type}", data)
    Rails.cache.write(Vectorsearch.action_cache_key(@user.id, id), { type: type.to_s, data: data, label: label }, expires_in: PROPOSAL_TTL)
    @proposals << { id: id, label: label }

    "Azione proposta: #{label}. Non è ancora eseguita: l'utente deve confermarla con il pulsante sotto la tua risposta."
  end

  # Checks: nil when the action can run, otherwise the reason for the model
  ##

  def check_projects_create(data)
    return "Non hai i permessi per creare progetti" unless @user.policy?("projects_create")
    return "Contatto CRM non trovato" if data[:contact_id].present? && !Contact.exists?(data[:contact_id])

    project_errors(Project.new(project_attributes(data)))
  end

  def check_projects_update(data)
    return "Non hai i permessi per modificare i progetti" unless @user.policy?("projects_edit")
    project = accessible_projects.find_by(id: data[:project_id])
    return "Progetto non trovato" unless project
    return "Nessuna modifica indicata" if project_attributes(data).empty?
    return "Contatto CRM non trovato" if data[:contact_id].present? && !Contact.exists?(data[:contact_id])

    project.assign_attributes(project_attributes(data))
    project_errors(project)
  end

  def check_projects_duplicate(data)
    return "Non hai i permessi per creare progetti" unless @user.policy?("projects_create")
    source = accessible_projects.find_by(id: data[:source_project_id])
    return "Progetto da copiare non trovato" unless source

    project_errors(Project.new(duplicate_attributes(source, data)))
  end

  def check_tasks_create(data)
    return "Non hai i permessi per creare task" unless @user.policy?("tasks_create")
    return "Il titolo del task è obbligatorio" if data[:title].blank?
    return "Utente assegnatario non trovato" unless User.exists?(data[:user_id])
    return "Scadenza non valida, usa il formato YYYY-MM-DD" if data[:deadline].present? && !valid_date?(data[:deadline])
    return "La checklist deve essere un array JSON di stringhe" unless parse_checklist(data[:checklist])
    return nil if data[:procedure_id].blank?

    procedure = Procedure.find_by(id: data[:procedure_id])
    return "Board non trovata" unless procedure
    return "Stato della board non trovato" unless procedure.procedures_statuses.exists?(data[:procedure_status_id])
    # a member-restricted user can only file tasks on boards of projects they can access
    "Non hai i permessi per creare task su questa board" if restricted_to_member_projects? && !accessible_projects.exists?(procedure.project_id)
  end

  def check_tasks_complete(data)
    return "Non hai i permessi per completare task" unless @user.policy?("tasks_complete")
    task = accessible_tasks.find_by(id: data[:task_id])
    return "Task non trovato" unless task

    "Il task è già completato" if task.completed
  end

  def check_tasks_comment(data)
    return "Non hai i permessi per commentare i task" unless @user.policy?("tasks_comment")
    return "Task non trovato" unless accessible_tasks.exists?(data[:task_id])

    "Il commento non può essere vuoto" if data[:content].blank?
  end

  def check_crm_communication_log_create(data)
    return "Non hai i permessi per usare il CRM" unless can_access_crm?
    return "Comunicazione non trovata" unless Communication.exists?(data[:communication_id])

    "La nota non può essere vuota" if data[:content].blank?
  end

  def check_crm_follow_up_create(data)
    return "Non hai i permessi per usare il CRM" unless can_access_crm?
    communication = Communication.find_by(id: data[:communication_id])
    return "Comunicazione non trovata" unless communication

    "I follow-up si registrano solo su comunicazioni inviate" unless communication.sent?
  end

  # Labels: built from the stored data, not from the model's text, so the
  # button shows exactly what will run
  ##

  def label_projects_create(data)
    contact = Contact.find_by(id: data[:contact_id]) if data[:contact_id].present?

    [
      "crea il progetto «#{data[:name]}» (#{data[:year]})",
      ("codice #{data[:code].upcase}" if data[:code].present?),
      ("contatto #{contact.name}" if contact)
    ].compact.join(", ")
  end

  def label_projects_update(data)
    project = Project.find(data[:project_id])
    changes = project_attributes(data).map do |field, value|
      value = Contact.find_by(id: value)&.name || "nessuno" if field == :contact_id
      "#{Project.human_attribute_name(field).downcase} «#{value.to_s.truncate(100)}»"
    end

    "modifica il progetto «#{project.name}»: #{changes.join(', ')}"
  end

  def label_projects_duplicate(data)
    source = Project.find(data[:source_project_id])
    attributes = duplicate_attributes(source, data)
    copies = duplicate_copies(source)

    [
      "crea il progetto «#{attributes[:name]}» (#{attributes[:year]}) copiando «#{source.name}»",
      ("contatto #{source.contact.name}" if source.contact),
      ("cartella #{source.folder.name}" if source.folder),
      ("#{copies.join(' e ')}" if copies.any?)
    ].compact.join(", ")
  end

  def label_tasks_create(data)
    procedure = Procedure.find_by(id: data[:procedure_id]) if data[:procedure_id].present?
    checklist = parse_checklist(data[:checklist])

    [
      "crea il task «#{data[:title]}» assegnato a #{User.find(data[:user_id]).complete_name}",
      ("scadenza #{Date.parse(data[:deadline]).strftime('%d/%m/%Y')}" if data[:deadline].present?),
      ("board #{procedure.name}" if procedure),
      ("#{checklist.size} voci di checklist" if checklist.any?)
    ].compact.join(", ")
  end

  def label_tasks_complete(data)
    "completa il task «#{Task.find(data[:task_id]).title}»"
  end

  def label_tasks_comment(data)
    "commenta il task «#{Task.find(data[:task_id]).title}»: «#{data[:content].truncate(200)}»"
  end

  def label_crm_communication_log_create(data)
    "aggiungi una nota alla comunicazione #{communication_name(data)}: «#{data[:content].truncate(200)}»"
  end

  def label_crm_follow_up_create(data)
    "registra un follow-up con data di oggi sulla comunicazione #{communication_name(data)}"
  end

  # Performs: run only from #execute, after the checks
  ##

  def perform_projects_create(data)
    project = Project.new(project_attributes(data))
    saved = Project.transaction do
      next false unless project.save

      # like the form default: the creator joins the project, so a
      # member-restricted user can still see it
      project.projects_members.create!(user: @user, role: " - ")
      true
    end
    return "Progetto non creato: #{project.errors.full_messages.to_sentence}" unless saved

    "Progetto «#{project.name}» creato (ID: #{project.id}, codice #{project.code})."
  end

  def perform_projects_update(data)
    project = Project.find(data[:project_id])
    return "Progetto non modificato: #{project.errors.full_messages.to_sentence}" unless project.update(project_attributes(data))

    "Progetto «#{project.name}» aggiornato."
  end

  # Boards are never shared between projects: each one is cloned as a new,
  # empty board of the new project.
  def perform_projects_duplicate(data)
    source = Project.find(data[:source_project_id])
    project = Project.new(duplicate_attributes(source, data))

    saved = Project.transaction do
      next false unless project.save

      source.folder.folders_items.create!(resource: project) if source.folder
      members = copy_members?(source) ? source.projects_members : []
      members.each { |member| project.projects_members.create!(user_id: member.user_id, role: member.role) }
      project.projects_members.create!(user: @user, role: " - ") unless project.projects_members.exists?(user_id: @user.id)
      boards_to_copy(source).each { |board| project.procedures.new.clone(board, board.name) }
      true
    end
    return "Progetto non creato: #{project.errors.full_messages.to_sentence}" unless saved

    "Progetto «#{project.name}» creato copiando «#{source.name}» (ID: #{project.id}, codice #{project.code})."
  end

  def perform_tasks_create(data)
    task = Task.new(
      user_id: data[:user_id],
      title: data[:title],
      deadline: data[:deadline],
      tasks_checks_texts: parse_checklist(data[:checklist])
    )
    # same acceptance rule as TasksController#create_action
    task.accepted = false if Setting.get("functionalities_task_acceptance") && !@user.policy?("tasks_acceptance")

    # the board placement rolls back with the task
    saved = Task.transaction do
      next false unless task.save

      task.procedures_items.create!(procedure_id: data[:procedure_id], procedures_status_id: data[:procedure_status_id]) if data[:procedure_id].present?
      true
    end
    return "Task non creato: #{task.errors.full_messages.to_sentence}" unless saved

    "Task «#{task.title}» creato (ID: #{task.id})."
  end

  def perform_tasks_complete(data)
    task = Task.find(data[:task_id])
    return "Task non completato: #{task.errors.full_messages.to_sentence}" unless task.update(completed: true)

    "Task «#{task.title}» completato."
  end

  def perform_tasks_comment(data)
    task = Task.find(data[:task_id])
    comment = task.tasks_comments.create(content: data[:content], user_id: @user.id)
    return "Commento non salvato: #{comment.errors.full_messages.to_sentence}" unless comment.persisted?

    "Commento aggiunto al task «#{task.title}»."
  end

  def perform_crm_communication_log_create(data)
    communication = Communication.find(data[:communication_id])
    # rich text: simple_format keeps the line breaks and sanitizes the text
    log = communication.communications_logs.create(content: ActionController::Base.helpers.simple_format(data[:content]), user: @user)
    return "Nota non salvata: #{log.errors.full_messages.to_sentence}" unless log.persisted?

    "Nota aggiunta alla comunicazione #{communication_name(data)}."
  end

  def perform_crm_follow_up_create(data)
    communication = Communication.find(data[:communication_id])
    return "Follow-up non registrato: #{communication.errors.full_messages.to_sentence}" unless communication.register_follow_up(Date.today, @user)

    "Follow-up registrato sulla comunicazione #{communication_name(data)}."
  end

  # Helpers
  ##

  # only the fields the model gave, so an update leaves the others untouched
  def project_attributes(data)
    data.to_h.symbolize_keys.slice(*PROJECT_FIELDS).compact
  end

  def duplicate_attributes(source, data)
    {
      name: data[:name],
      year: data[:year].presence || source.year,
      code: data[:code],
      description: data[:description].presence || source.description,
      contact_id: source.contact_id
    }
  end

  # members and boards follow the same policies the project page asks for
  def copy_members?(source)
    @user.policy?("projects_manage_members") && source.projects_members.any?
  end

  def boards_to_copy(source)
    @user.policy?("projects_manage_procedures") ? source.procedures.not_archived : Procedure.none
  end

  def duplicate_copies(source)
    members = copy_members?(source) ? source.projects_members.count : 0
    boards = boards_to_copy(source).count

    [
      ("#{members} #{members == 1 ? "membro" : "membri"}" if members.positive?),
      ("#{boards} #{boards == 1 ? "board vuota" : "board vuote"}" if boards.positive?)
    ].compact
  end

  def project_errors(project)
    "Progetto non valido: #{project.errors.full_messages.to_sentence}" unless project.valid?
  end

  def communication_name(data)
    communication = Communication.includes(:contact, :campaign).find(data[:communication_id])
    "con #{communication.contact.name} (campagna #{communication.campaign.name})"
  end

  def valid_date?(value)
    Date.iso8601(value.to_s)
    true
  rescue Date::Error
    false
  end

  # [] when blank, nil when it is not a JSON array of strings
  def parse_checklist(value)
    return [] if value.blank?

    items = JSON.parse(value)
    items if items.is_a?(Array) && items.all?(String)
  rescue JSON::ParserError
    nil
  end
end
