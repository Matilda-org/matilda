return unless Rails.env.development?

# Demo data for a fictional web agency ("Umbrella Studio").
# Dates are always relative to Date.today so a fresh `rails db:seed`
# produces a live-looking workspace (useful for screenshots and demos).

admin = User.create!(
  name: "Admin",
  surname: "Admin",
  email: "admin@mail.com",
  password: "Password1!",
  password_confirmation: "Password1!"
)

admin.update_policies(Users::Policy.policies.keys.reject { |key| key == "only_data_projects_as_member" })

# Settings
##

Setting.set("infos_company_name", "Umbrella Studio")
Setting.set("infos_company_website", "umbrellastudio.it")
Setting.set("infos_company_vat", "IT 01787180932")
Setting.set("infos_company_pec", "umbrellastudio@pec.it")
Setting.set("infos_company_email", "hello@umbrellastudio.it")

# Users
##

[
  "Marco Rossi",
  "Marco Adami",
  "Luigi Palmieri",
  "Davide Sassola",
  "Anna Ottoni",
  "Sara Parker",
  "Ilaria Matiussi"
].each do |complete_name|
  name, surname = complete_name.split(" ")

  User.create!(
    name: name,
    surname: surname,
    email: "#{name}.#{surname}@mail.com".downcase,
    password: "Password1!",
    password_confirmation: "Password1!"
  )
end

users = User.all.to_a

# Folders
##

folders = [
  "Clienti Hospitality",
  "Clienti E-commerce",
  "Clienti Corporate",
  "Digital Marketing",
  "Progetti interni"
].map { |name| Folder.create!(name: name) }

# Procedure model for project boards
##

procedure_model_tasks = Procedure.create!(
  name: "Workflow sviluppo",
  description: "Flusso operativo standard dei progetti di sviluppo.",
  resources_type: "tasks",
  model: true
)

board_statuses = [
  [ "To-do", nil ],
  [ "In lavorazione", "#19405d" ],
  [ "Review", "#ff6b35" ],
  [ "Completato", "#2e7d32" ]
]

board_statuses.each_with_index do |(title, color), index|
  procedure_model_tasks.procedures_statuses.create!(
    title: title,
    color: color,
    order: index + 1
  )
end

[
  [ "Kickoff e raccolta requisiti", 2 ],
  [ "Wireframe e architettura", 4 ],
  [ "Design UI", 8 ],
  [ "Sviluppo frontend", 16 ],
  [ "Sviluppo backend", 16 ],
  [ "QA e rilascio", 6 ]
].each do |title, hours|
  procedure_model_tasks.procedures_statuses.first.procedures_items.create!(
    title: title,
    model_data: {
      title: title,
      description: "Attività standard del flusso di sviluppo.",
      deadline: Date.today + rand(5..30).days,
      time_estimate: hours * 3600
    }
  )
end

# Projects
##

task_titles_pool = [
  "Setup ambiente di staging",
  "Wireframe homepage e sezioni interne",
  "Design UI pagina prodotto",
  "Sviluppo componente prenotazioni",
  "Integrazione gateway di pagamento",
  "Migrazione contenuti dal vecchio sito",
  "Ottimizzazione SEO on-page",
  "Configurazione analytics e consensi",
  "Test cross-browser e mobile",
  "Fix segnalazioni QA sprint corrente",
  "Aggiornamento dipendenze e sicurezza",
  "Preparazione demo per il cliente",
  "Revisione copy con il cliente",
  "Setup campagne Meta Ads",
  "Report mensile performance",
  "Backup e monitoraggio uptime"
]

check_texts_pool = [
  "Verificare versione mobile",
  "Aggiornare la documentazione",
  "Chiedere conferma al cliente",
  "Testare su Safari",
  "Controllare tempi di caricamento",
  "Allineare il team in daily"
]

comment_texts_pool = [
  "Ho aggiornato la task con le ultime richieste del cliente.",
  "Manca solo la verifica finale, poi possiamo chiudere.",
  "Attenzione: il cliente ha chiesto una modifica al layout.",
  "Fatto il deploy in staging, potete verificare?",
  "Ci sono novità su questa attività?"
]

projects_data = [
  { name: "Hotel Bescolo - restyling sito web", folder: 0, budget: true },
  { name: "Hotel Marittima - booking engine", folder: 0, budget: true },
  { name: "Antony Boss - e-commerce moda", folder: 1, budget: true },
  { name: "Arcori - piattaforma B2B", folder: 1, budget: false },
  { name: "Macox - sito corporate", folder: 2, budget: false },
  { name: "Inoxbiella - catalogo prodotti", folder: 2, budget: true },
  { name: "Sammontana - campagna estiva", folder: 3, budget: false },
  { name: "Libri Free - digital marketing", folder: 3, budget: false },
  { name: "BuyMyDay - piattaforma web", folder: 1, budget: true },
  { name: "Cagliari Calcio - sito ufficiale", folder: 2, budget: true },
  { name: "Umbrella Studio - sito interno", folder: 4, budget: false },
  { name: "Umbrella Studio - brand refresh", folder: 4, budget: false }
]

showcase_projects = []

projects_data.each_with_index do |data, project_index|
  project = Project.create!(
    name: data[:name],
    year: Date.today.year - rand(0..2),
    description: "Progetto #{data[:name].split(' - ').last} per il cliente #{data[:name].split(' - ').first}.",
    budget_management: data[:budget],
    budget_money: data[:budget] ? rand(8..25) * 1000 : 0,
    budget_time: data[:budget] ? rand(40..160) * 3600 : 0
  )

  Folders::Item.create!(
    resource_type: "Project",
    resource_id: project.id,
    folder_id: folders[data[:folder]].id
  )

  # pin some projects on the admin dashboard
  if project_index < 4
    admin.users_prefers.create!(resource_type: "Project", resource_id: project.id)
  end

  # members
  users.sample(rand(3..5)).each do |member|
    project.projects_members.create!(
      user_id: member.id,
      role: %w[Developer Designer Marketing PM].sample
    )
  end

  # logs
  [
    "Call di allineamento con il cliente",
    "Riunione interna di pianificazione",
    "Mail dal cliente con feedback",
    "Consegna materiali dal fornitore",
    "Demo intermedia con il cliente"
  ].sample(rand(2..4)).each do |title|
    project.projects_logs.create!(
      title: title,
      content: "Note della giornata: allineamento su avanzamento, prossimi step e scadenze condivise con il team.",
      date: Date.today - rand(0..30).days,
      user_id: users.sample.id
    )
  end

  # attachments
  [
    "Preventivo firmato",
    "Presentazione progetto",
    "Grafiche definitive",
    "Documentazione tecnica",
    "Contratto di manutenzione"
  ].sample(rand(1..3)).each do |title|
    project.projects_attachments.create!(
      title: title,
      description: "Documento condiviso con il cliente.",
      version: 1,
      date: Date.today - rand(0..60).days
    )
  end

  # project board with the standard workflow statuses
  procedure = project.procedures.create!(name: "Operativo", resources_type: "tasks")
  statuses = board_statuses.each_with_index.map do |(title, color), index|
    procedure.procedures_statuses.create!(title: title, color: color, order: index + 1)
  end

  # tasks distributed on the board and around today's date
  task_titles_pool.sample(rand(5..8)).each_with_index do |title, index|
    # deterministic spread across the board columns (heavier on the first ones)
    status = statuses[[ 0, 1, 0, 2, 1, 3, 0, 1 ][index % 8]]
    completed = status == statuses.last
    # estimates/spent are stored in seconds
    time_estimate = [ 30, 60, 120, 240, 480 ].sample * 60

    task = project.tasks.create!(
      title: title,
      content: "Attività del progetto #{project.name}.",
      user: [ users.sample, users.sample, nil ].sample,
      deadline: completed ? Date.today - rand(1..3).days : Date.today + [ -2, 0, 0, 1, 1, 2, 2, 3, 4, 6 ].sample.days,
      time_estimate: time_estimate,
      time_spent: completed ? time_estimate + rand(-30..30) * 60 : (rand < 0.5 ? rand(0..time_estimate) : 0),
      completed: completed,
      completed_at: completed ? Time.current - rand(1..10).days : nil,
      accepted: true
    )

    status.procedures_items.create!(resource: task)

    # checklists on some tasks
    if rand < 0.4
      check_texts_pool.sample(rand(2..3)).each_with_index do |text, check_index|
        task.tasks_checks.create!(text: text, checked: rand < 0.5, order: check_index + 1)
      end
    end

    # comments on some tasks
    if rand < 0.3
      rand(1..2).times do
        task.tasks_comments.create!(content: comment_texts_pool.sample, user: users.sample)
      end
    end
  end

  showcase_projects << project
end

# One task due today per user so the tasks "people" view looks busy
##

[
  "Call di allineamento settimanale",
  "Revisione contenuti homepage",
  "Controllo campagne attive",
  "Aggiornamento board di progetto",
  "Verifica ticket assistenza",
  "Preparazione riunione con il cliente",
  "Controllo backup notturni",
  "Revisione preventivo in uscita"
].each_with_index do |title, index|
  user = users[index % users.size]
  project = showcase_projects[index % showcase_projects.size]

  project.tasks.create!(
    title: title,
    user: user,
    deadline: Date.today,
    time_estimate: [ 30, 60, 90, 120 ].sample * 60,
    accepted: true
  )
end

# Company board with projects pipeline
##

pipeline = Procedure.create!(
  name: "Pipeline commesse",
  description: "Stato di avanzamento delle commesse attive.",
  resources_type: "projects"
)

pipeline_statuses = [
  [ "Preventivo", nil ],
  [ "In lavorazione", "#19405d" ],
  [ "Review cliente", "#ff6b35" ],
  [ "Consegnato", "#2e7d32" ]
].each_with_index.map do |(title, color), index|
  pipeline.procedures_statuses.create!(title: title, color: color, order: index + 1)
end

showcase_projects.each_with_index do |project, index|
  pipeline_statuses[index % pipeline_statuses.size].procedures_items.create!(resource: project)
end

# Posts (company feed)
##

[
  { content: "Benvenuta a Ilaria nel team design! 🎉", tags: "team" },
  { content: "Venerdì alle 15:00 demo interna del nuovo booking engine, ci trovate in sala riunioni.", tags: "eventi" },
  { content: "Ricordatevi di registrare le ore sulle task entro fine settimana.", tags: "operativo" },
  { content: "Il sito di Hotel Bescolo è online! Grazie a tutto il team per il lavoro. 🚀", tags: "rilasci" },
  { content: "Nuova guida interna per il setup dell'ambiente di sviluppo disponibile nella documentazione.", tags: "documentazione" }
].each do |post_data|
  Post.create!(
    content: post_data[:content],
    tags: post_data[:tags],
    user_id: users.sample.id
  )
end

# Credentials
##

[
  [ "Hosting - Hotel Bescolo", "admin@hotelbescolo.it" ],
  [ "Registrar - dominio arcori.com", "gestione@umbrellastudio.it" ],
  [ "Meta Business - Sammontana", "ads@umbrellastudio.it" ],
  [ "SMTP transazionale - BuyMyDay", "noreply@buymyday.com" ],
  [ "Dashboard analytics - Macox", "analytics@umbrellastudio.it" ]
].each do |name, username|
  Credential.create!(
    name: name,
    secure_username: username,
    secure_password: SecureRandom.base58(16),
    secure_content: "Credenziali di servizio generate per l'ambiente demo."
  )
end

# CRM (contacts / campaigns / communications)
##

contacts_data = [
  { name: "Hotel Bescolo", description: "Hotel 4 stelle sulla riviera, cliente storico per sito e booking." },
  { name: "Hotel Marittima", description: "Struttura ricettiva con booking engine gestito da noi." },
  { name: "Antony Boss", description: "Brand moda con e-commerce in gestione continuativa." },
  { name: "Arcori", description: "Azienda B2B componentistica, piattaforma ordini rivenditori." },
  { name: "Macox", description: "Corporate manifatturiero, sito istituzionale multilingua." },
  { name: "Inoxbiella", description: "Produzione acciaio inox, catalogo prodotti online." },
  { name: "Sammontana", description: "Campagne digital stagionali per il brand gelati." },
  { name: "Libri Free", description: "Libreria online, attività di digital marketing mensile." },
  { name: "BuyMyDay", description: "Startup piattaforma esperienze regalo." },
  { name: "Cagliari Calcio", description: "Società sportiva, sito ufficiale e area news." },
  { name: "Ristorante Da Remo", description: "Interessati a sito con prenotazione tavoli." },
  { name: "Clinica San Marco", description: "Richiesta per portale prenotazioni visite, primo contatto da referral." },
  { name: "GreenBike Rental", description: "Noleggio bici turistico, valutano e-commerce per tour prenotabili." },
  { name: "Pastificio Gallo", description: "Pastificio artigianale, possibile e-commerce." },
  { name: "Studio Legale Ferraris", description: "Studio legale, sito vetrina gestito in passato." }
]

contacts_data.each do |data|
  Contact.create!(
    name: data[:name],
    description: data[:description],
    email: "info@#{data[:name].parameterize(separator: '')}.it",
    phone: "0#{rand(2..9)} #{rand(1000000..9999999)}",
    website: "https://www.#{data[:name].parameterize(separator: '')}.it",
    vat_number: "IT #{rand(10000000000..99999999999)}"
  )
end

# link demo projects to their contact (project names are "<contact> - <subject>")
Contact.find_each do |contact|
  Project.where("name LIKE ?", "#{contact.name} - %").update_all(contact_id: contact.id)
end

# campaigns with communications spread across the kanban states
communication_note_texts = [
  "Inviata mail con presentazione e listino.",
  "Richiamare la prossima settimana, referente in ferie.",
  "Interessati ma vogliono confrontare altri preventivi.",
  "Chiesto materiale aggiuntivo sul portfolio.",
  "Contatto molto reattivo, buone possibilità."
]

campaigns_data = [
  { name: "Preventivi siti #{Date.today.year}", description: "Proposte di restyling e nuovi siti per contatti caldi." },
  { name: "Upsell manutenzione", description: "Offerta piano manutenzione annuale ai clienti storici." },
  { name: "Lancio servizio SEO", description: "Presentazione del nuovo pacchetto SEO trimestrale." }
]

campaigns_data.each_with_index do |data, campaign_index|
  campaign = Campaign.create!(name: data[:name], description: data[:description])

  Contact.order(:id).offset(campaign_index * 3).limit(8).each_with_index do |contact, index|
    communication = campaign.communications.create!(contact: contact)

    # spread across states: 2 to_send, then sent / lost / won
    case index % 4
    when 1
      communication.mark_sent(Date.today - rand(2..15).days)
      # follow-up sparsi tra l'invio e oggi, mai nel futuro
      elapsed = (Date.today - communication.sent_date).to_i
      rand(0..3).times { communication.register_follow_up(communication.sent_date + rand(0..elapsed), users.sample) }
    when 2
      communication.mark_sent(Date.today - rand(10..30).days)
      communication.register_follow_up(communication.sent_date + rand(1..5), users.sample)
      communication.mark_closed("lost", Date.today - rand(1..5).days)
    when 3
      communication.mark_sent(Date.today - rand(10..30).days)
      communication.mark_closed("won", Date.today - rand(1..5).days)
    end

    # some text notes
    rand(0..2).times do
      communication.communications_logs.create!(
        content: communication_note_texts.sample,
        user_id: users.sample.id
      )
    end
  end
end


# Project risks demo data
##

risk_projects_data = [
  {
    name: "Cliente Bloccato - migrazione ecommerce",
    description: "Progetto demo con task scaduti e attivita ferme.",
    budget_time: 40.hours,
    tasks: [
      { title: "Recuperare accessi produzione", deadline: 10.days.ago, user: nil, time_estimate: 4.hours, time_spent: 5.hours },
      { title: "Validare piano redirect SEO", deadline: 4.days.ago, user: users.sample, time_estimate: 6.hours, time_spent: 8.hours },
      { title: "Aggiornare cliente sul blocco", deadline: Date.today, user: nil, time_estimate: 1.hour, time_spent: 0 }
    ]
  },
  {
    name: "Budget Critico - restyling area riservata",
    description: "Progetto demo con budget tempo quasi esaurito.",
    budget_time: 24.hours,
    tasks: [
      { title: "Refactoring flusso login", deadline: 2.days.from_now, user: users.sample, time_estimate: 8.hours, time_spent: 12.hours },
      { title: "Fix responsive dashboard cliente", deadline: 5.days.from_now, user: users.sample, time_estimate: 6.hours, time_spent: 8.hours },
      { title: "QA regressione permessi", deadline: 1.week.from_now, user: nil, time_estimate: 4.hours, time_spent: 3.hours }
    ]
  },
  {
    name: "Senza Owner - campagna lead generation",
    description: "Progetto demo con molte attivita non assegnate.",
    budget_time: 30.hours,
    tasks: [
      { title: "Definire audience Meta Ads", deadline: 3.days.from_now, user: nil, time_estimate: 2.hours, time_spent: 0 },
      { title: "Preparare copy landing", deadline: 4.days.from_now, user: nil, time_estimate: 3.hours, time_spent: 0 },
      { title: "Configurare tracciamenti conversione", deadline: 5.days.from_now, user: nil, time_estimate: 4.hours, time_spent: 0 }
    ]
  }
]

risk_projects_data.each do |project_data|
  project = Project.create!(
    name: project_data[:name],
    year: Date.today.year,
    description: project_data[:description],
    budget_management: true,
    budget_money: rand(8000..20_000),
    budget_time: project_data[:budget_time]
  )

  users.sample(4).each do |project_user|
    project.projects_members.create!(user_id: project_user.id, role: %w[Developer Designer Marketing PM].sample)
  end

  project_data[:tasks].each do |task_data|
    project.tasks.create!(
      title: task_data[:title],
      deadline: task_data[:deadline],
      user: task_data[:user],
      time_estimate: task_data[:time_estimate],
      time_spent: task_data[:time_spent],
      accepted: true
    )
  end

  # Make one demo project look stale in the risk report.
  project.update_columns(updated_at: 21.days.ago) if project.name.start_with?("Cliente Bloccato")
end

# User logs (recent searches for the quick-search widget)
##

users.each do |user|
  10.times do
    Users::Log.create!(
      user_id: user.id,
      typology: :search,
      value: Project.all.sample.name
    )
  end
end
