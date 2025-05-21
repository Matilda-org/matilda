class VectorsearchTools::QueryDatabaseTool
  extend Langchain::ToolDefinition

  # Projects
  ##

  define_function :prjs, description: "Query list of projects" do
    property :archived, type: "boolean", description: "Filter archived projects", required: false
    property :year, type: "integer", description: "Filter projects by year", required: false
    property :user_id, type: "integer", description: "Filter projects by user membership", required: false
    property :search, type: "string", description: "Search projects by name or description", required: false
  end

  def prjs(data)
    archived = data[:archived]
    year = data[:year]
    user_id = data[:user_id]
    search = data[:search]

    projects = Project.all.includes(:folder, :projects_members)
    projects = Project.where(archived: !!archived)
    projects = projects.where(year: year) if year.present?
    projects = projects.joins(:projects_members).where(projects_members: { user_id: user_id }) if user_id.present?
    projects = projects.search(search) if search.present?

    projects.map { |p| project_to_string(p) }.join("\n")
  end

  # Projects Logs
  ##

  define_function :prjs_logs, description: "Query project notes" do
    property :project_id, type: "integer", description: "Project ID", required: true
  end

  def prjs_logs(data)
    project = Project.find_by_id(data[:project_id])
    return "Progetto non trovato" unless project

    project.projects_logs.map { |log| project_log_to_string(log) }.join("\n")
  end

  define_function :prjs_log_content, description: "Get the content of a project note" do
    property :projects_log_id, type: "integer", description: "Note ID", required: true
  end

  def prjs_log_content(data)
    log = Projects::Log.find_by_id(data[:project_log_id])
    return "Nota non trovata" unless log

    log.content
  end

  # Projects Attachments
  ##

  define_function :prjs_atchs, description: "Query project attachments" do
    property :project_id, type: "integer", description: "Project ID", required: true
  end

  def prjs_atchs(data)
    project = Project.find_by_id(data[:project_id])
    return "Progetto non trovato" unless project

    project.attachments.map { |a| project_attachment_to_string(a) }.join("\n")
  end

  # Tasks
  ##

  define_function :tasks, description: "Query tasks" do
    property :project_id, type: "integer", description: "Project ID", required: false
    property :user_id, type: "integer", description: "Filter tasks by user assignment", required: false
    property :completed, type: "boolean", description: "Filter completed tasks", required: false
    property :deadline, type: "string", description: "Filter tasks by deadline (YYYY-MM-DD)", required: false
    property :search, type: "string", description: "Search tasks by title", required: false
  end

  def tasks(data)
    project_id = data[:project_id]
    user_id = data[:user_id]
    completed = data[:completed]
    deadline = data[:deadline]
    search = data[:search]

    tasks = Task.all
    tasks = Task.where(project_id: project_id) if project_id.present?
    tasks = tasks.where(user_id: user_id) if user_id.present?
    tasks = tasks.where(completed: !!completed)
    tasks = tasks.where(deadline: deadline) if deadline.present?
    tasks = tasks.search(search) if search.present?

    tasks.map { |t| task_to_string(t) }.join("\n")
  end

  define_function :tasks_create, description: "Create a new task (use task also for reminder, to-dos ecc.)" do
    property :user_id, type: "integer", description: "User ID", required: true
    property :title, type: "string", description: "Task title", required: true
    property :description, type: "string", description: "Task description", required: false
    property :deadline, type: "string", description: "Task deadline (YYYY-MM-DD)", required: false
    property :checklist, type: "string", description: "Task checklist items (JSON array of strings)", required: false
    property :procedure_id, type: "integer", description: "Board ID where the task should be created (require also procedure_status_id)", required: false
    property :procedure_status_id, type: "integer", description: "Board status ID where the task should be created", required: false
  end

  def tasks_create(data)
    user_id = data[:user_id]
    title = data[:title]
    description = data[:description]
    deadline = data[:deadline]
    checklist = data[:checklist].blank? ? [] : JSON.parse(data[:checklist])
    procedure_id = data[:procedure_id]
    procedure_status_id = data[:procedure_status_id]

    task = Task.create!(
      user_id: user_id,
      title: title,
      description: description,
      deadline: deadline,
      tasks_checks_texts: checklist
    )

    if procedure_id.present? && procedure_status_id.present?
      task.procedures_items.create!(
        procedure_id: procedure_id,
        procedures_status_id: procedure_status_id
      )
    end
  end

  # Credentials
  ##

  define_function :credentials, description: "Query credentials" do
    property :search, type: "string", description: "Search credentials by name or description", required: false
  end

  def credentials(data)
    search = data[:search]

    credentials = Credential.all
    credentials = credentials.search(search) if search.present?

    credentials.map { |c| credential_to_string(c) }.join("\n")
  end

  private

  # To string methods
  ##

  def project_to_string(project)
    procedures_infos = procedures_infos(project.procedures)
    procedures_as_item_infos = procedures_as_item_infos(project.procedures_items)

    "
    Il progetto #{project.name} è iniziato nel #{project.year}, ha il codice #{project.code}, il suo ID è #{project.id}.
    In questo momento il progetto è #{project.archived ? 'archiviato' : 'in fase di sviluppo'}.
    #{"Il progetto si trova nella cartella #{project.folder.name}." if project.folder}
    #{"Il progetto è stato archiviato per il seguente motivo: #{Project.archived_reason_string(project.archived_reason)}." if project.archived}
    Il progetto ha #{project.tasks.completed.count} task completati e #{project.tasks.not_completed.count} task non completati.
    Per il progetto sono stati spesi #{project.track_time_string(project.cached_time_spent)} di lavoro.
    #{"Il progetto ha un budget di #{project.budget_money}€ per un totale #{project.track_time_string(project.budget_time)} stimati. Il costo orario è di #{project.budget_money_per_time}€/h." if project.budget_management}
    #{"Questa è la descrizione del progetto: #{project.description}." unless project.description.blank?}
    #{"Questa è la lista di board associate al progetto:\n #{procedures_infos}" unless procedures_infos.blank?}
    #{"Qesta è la lista delle board in cui si trova il progetto:\n#{procedures_as_item_infos}" unless procedures_as_item_infos.blank?}
    ".squish
  end

  def project_log_to_string(log)
    "
    Il giorno #{log.date.strftime('%d/%m/%Y')} è stata presa la nota #{log.title} con ID #{log.id}.
    ".squish
  end

  def project_attachment_to_string(attachment)
    "
    L'allegato #{attachment.title} ha ID #{attachment.id}.
    L'allegato è di tipo #{attachment.typology_string}.
    #{"L'allegato fa riferimento alla data #{attachment.date.strftime('%d/%m/%Y')}." if attachment.date}
    #{"L'allegato è alla versione #{attachment.version}." if attachment.version}
    #{"Questa è la descrizione dell'allegato: #{attachment.description}." unless attachment.description.blank?}
    "
  end

  def task_to_string(task)
    procedures_as_item_infos = procedures_as_item_infos(task.procedures_items)

    "
    Il task #{task.title} ha ID #{task.id}.
    Il task è #{task.completed ? 'completato' : 'in corso'}.
    #{"Il task fa riferimento al progetto #{task.project.name} (ID: #{task.project_id})." if task.project}
    #{"Il task è assegnato a #{task.user.complete_name} (ID: #{task.user_id})." if task.user}
    #{"Il task è stato completato il #{task.completed_at.strftime('%d/%m/%Y')}." if task.completed}
    #{"Il task ha una scadenza per il giorno #{task.deadline.strftime('%d/%m/%Y')}." if task.deadline}
    #{"Il task è scaduto da #{task.distance_of_time_in_words_to_now(task.deadline)}." if task.deadline && task.deadline.past?}
    #{"Il task scade tra #{task.distance_of_time_in_words_to_now(task.deadline)}." if task.deadline && !task.deadline.past?}
    #{"Il task è stato stimato #{task.time_estimate_as_string} di lavoro." if task.time_estimate}
    #{"Il task ha richiesto #{task.time_spent_as_string} di lavoro." if task.time_spent}
    #{"Questa è la descrizione del task: #{task.description}." unless task.description.blank?}
    ##{"Qesta è la lista delle board in cui si trova il task:\n#{procedures_as_item_infos}" unless procedures_as_item_infos.blank?}
    ".squish
  end

  def credential_to_string(credential)
    "
    Le credenziali #{credential.name} hanno ID #{credential.id}.
    #{"Le credenziali hanno un username" unless credential.secure_username.blank?}.
    #{"Le credenziali hanno una password" unless credential.secure_password.blank?}.
    #{"Le credenziali hanno un contenuto" unless credential.secure_content.blank?}.
    #{"Le credenziali si trovano nella cartella #{credential.folder.name}." if credential.folder}
    ".squish
  end

  def procedures_infos(procedures)
    procedures_infos = ""

    procedures.map do |procedure|
      procedures_infos += "- La board #{procedure.name} ha ID #{procedure.id} è contiene i seguenti stati: #{procedure.procedures_statuses.map { |s| "#{s.title} (ID: #{s.id})" }.join(', ')}.\n"
    end

    procedures_infos
  end

  def procedures_as_item_infos(procedures_items)
    procedures_as_item_infos = ""

    procedures_items.includes(:procedure, :procedures_status).map do |procedure_item|
      procedures_as_item_infos += "- Nella board #{procedure_item.procedure.name} si trova nello stato #{procedure_item.procedures_status.title}.\n"
    end

    procedures_as_item_infos
  end
end
