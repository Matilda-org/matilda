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
  # TODO...
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
