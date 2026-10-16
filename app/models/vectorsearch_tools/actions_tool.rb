# Write tools of the chat assistant. Calling them writes nothing: each call
# stores a proposal and the user runs it with the "Conferma" button
# (Vectorsearch#confirm_action), which needs no AI call. The chat can also read
# web pages, so without the confirmation an instruction hidden in a page could
# act with the user's permissions.
class VectorsearchTools::ActionsTool
  extend Langchain::ToolDefinition
  include VectorsearchTools::Access

  ACTIONS = %w[tasks_create tasks_complete tasks_comment crm_communication_log_create crm_follow_up_create].freeze
  PROPOSAL_TTL = 1.day

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
