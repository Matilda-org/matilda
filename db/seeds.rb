return unless Rails.env.development?

user = User.create!(
  name: 'Admin',
  surname: 'Admin',
  email: 'admin@mail.com',
  password: 'Password1!',
  password_confirmation: 'Password1!'
)

user.update_policies(Users::Policy.policies.keys)

# Settings
##

Setting.set('infos_company_name', 'Google')
Setting.set('infos_company_website', 'google.com')
Setting.set('infos_company_vat', 'IT 01787180932')
Setting.set('infos_company_pec', 'google@pec.it')
Setting.set('infos_company_email', 'google@gmail.com')

# Users
##

[
  'Marco Rossi',
  'Marco Adami',
  'Luigi Palmieri',
  'Davide Sassola',
  'Anna Ottoni',
  'Sara Parker',
  'Ilaria Matiussi'
].each do |complete_name|
  name = complete_name.split(' ').first
  surname = complete_name.split(' ').last

  User.create!(
    name: name,
    surname: surname,
    email: "#{name}.#{surname}@mail.com".downcase,
    password: 'Password1!',
    password_confirmation: 'Password1!'
  )
end

# Folders
##

30.times do |index|
  Folder.create!(
    name: "Cartella #{index + 1}",
  )
end

# Procedures
##

# create a model for tasks
procedure_model_tasks = Procedure.create!(
  name: 'Modello tasks',
  description: Faker::Lorem.paragraph,
  resources_type: 'tasks',
  model: true
)

[
  'To-do',
  'Working',
  'Done'
].each_with_index do |title, index|
  procedure_model_tasks.procedures_statuses.create!(
    title: title,
    order: index + 1
  )
end

5.times do |index|
  procedure_model_tasks.procedures_statuses.first.procedures_items.create!(
    title: "Task #{index + 1}",
    model_data: {
      title: "Task #{index + 1}",
      description: Faker::Lorem.paragraph,
      deadline: Faker::Date.between(from: Date.today, to: 60.days.from_now),
      time_estimate: 60 * [ 15, 30, 60, 120 ].sample
    }
  )
end

# Projects
##

[
  'Hotel Bescolo - restiling sito web',
  'Hotel Marittima - restiling sito web',
  'BuyMyDay - sviluppo piattaforma web',
  'Antony Boss - sviluppo sito web',
  'Antony Boss - digital marketing',
  'Arcori - sito web',
  'Arcori - digital marketing',
  'Arcori - sviluppo piattaforma web',
  'Arcori - sviluppo sito web',
  'Cagliari Calcio - sviluppo sito web',
  'Macox - sviluppo sito web',
  'Macox - digital marketing',
  'Macox - sviluppo piattaforma web',
  'Inoxbiella - sviluppo sito web',
  'Inoxbiella - digital marketing',
  'Inoxbiella - sviluppo piattaforma web',
  'Sammontana - sviluppo sito web',
  'Sammontana - digital marketing',
  'Sammontana - sviluppo piattaforma web',
  'Libri Free - sviluppo sito web',
  'Libri Free - digital marketing',
  'Libri Free - sviluppo piattaforma web'
].each do |name|
  # create project
  project = Project.create!(
    name: name,
    year: Date.today.year.to_i - rand(0..5),
    description: Faker::Lorem.paragraph
  )

  # assign project to a folder
  if [ true, true, false ].sample
    Folders::Item.create!(
      resource_type: 'Project',
      resource_id: project.id,
      folder_id: Folder.all.sample.id
    )
  end

  # assing project to user prefers
  if [ true, false, false ].sample
    user.users_prefers.create!(
      resource_type: 'Project',
      resource_id: project.id
    )
  end

  # add members to project
  User.all.each do |user|
    project.projects_members.create!(
      user_id: user.id,
      role: %w[Developer Deisgner Marketing PM].sample
    )
  end

  # add logs to project
  [
    'Call con cliente',
    'Riunione con cliente',
    'Riunione interna',
    'Mail dal cliente',
    'Mail dal fornitore'
  ].sample(rand(1..3)).each do |title|
    project.projects_logs.create!(
      title: title,
      content: Faker::Lorem.paragraph,
      date: Faker::Date.between(from: 60.days.ago, to: Date.today),
      user_id: User.all.sample.id
    )
  end

  # add attachments to project
  [
    'Preventivo inviato',
    'Preventivo firmato',
    'Presentazione progetto',
    'Grafiche',
    'Documentazione sistema'
  ].sample(rand(1..4)).each do |title|
    project.projects_attachments.create!(
      title: title,
      description: Faker::Lorem.paragraph,
      version: 1,
      date: Faker::Date.between(from: 60.days.ago, to: Date.today)
    )
  end

  # add internal procedure to project
  procedure = project.procedures.new
  procedure.clone(procedure_model_tasks, 'Operativo', user_id: User.all.sample.id)
end

# User logs
#

User.all.each do |user|
  40.times do |index|
    Users::Log.create!(
      user_id: user.id,
      typology: :search,
      value: Project.all.sample.name,
    )
  end
end
