task create_default_admin: :environment do
  if User.exists?(email: "admin@mail.com")
    puts "🚨 Default admin user already exists"
    next
  end

  user = User.create!(
    name: "Admin",
    surname: "Admin",
    email: "admin@mail.com",
    password: "Password1!",
    password_confirmation: "Password1!"
  )
  user.update_policies(Users::Policy.policies.keys.reject { |p| p == :only_data_projects_as_member })

  puts "✅ Default admin user created with email: #{user.email} and password: Password1!"
end

task create_default_data: :environment do
  procedure_model_tasks = Procedure.create!(
    name: "Task operativi",
    description: "Procedure standard per la gestione dei task operativi",
    resources_type: "tasks",
    model: true
  )

  procedure_model_tasks.procedures_statuses.create!(
    title: "To-do",
    order: 0,
    color: "#1982c4"
  )

  procedure_model_tasks.procedures_statuses.create!(
    title: "In progress",
    order: 1,
    color: "#ffca3a"
  )

  procedure_model_tasks.procedures_statuses.create!(
    title: "Completati",
    order: 2,
    color: "#52a675"
  )

  project = Project.create!(
    name: "Inizio utilizzo di Matilda",
    year: Date.today.year.to_i,
    description: "Un primo progetto per iniziare a utilizzare Matilda",
  )

  procedure = project.procedures.new
  procedure.clone(procedure_model_tasks, "Task operativi", user_id: nil)

  User.all.each do |user|
    project.projects_members.create!(
      user_id: user.id,
      role: "Partecipante"
    )

    project.tasks.create!(
      title: "Accedi a Matilda",
      content: "Effettua il login con le tue credenziali",
      deadline: Date.tomorrow,
      time_estimate: 60 * 5,
      user_id: user.id,
      position_procedure_id: procedure.id
    )
  end
end

task add_all_policies_to_users: :environment do
  completed = 0
  total = User.count

  User.all.each do |user|
    unless user.update_policies(Users::Policy.policies.keys.reject { |p| p == :only_data_projects_as_member })
      puts "🚨 Failed to update policies for user with email: #{user.email}"
      next
    end

    completed += 1
  end

  puts "✅ All policies added to all users (#{completed}/#{total})"
end

task remove_all_policies_from_users: :environment do
  User.all.each do |user|
    user.users_policies.destroy_all
  end

  puts "✅ All policies removed from all users"
end
