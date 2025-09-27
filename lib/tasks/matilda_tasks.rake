namespace :matilda do
  task create_admin: :environment do
    if User.exists?(email: "admin@mail.com")
      puts "Admin user already exists"
      next
    end

    user = User.create!(
      name: "Admin",
      surname: "Admin",
      email: "admin@mail.com",
      password: "Password1!",
      password_confirmation: "Password1!"
    )
    user.update_policies(Users::Policy.policies.keys)
  end

  task users_add_policies: :environment do
    User.all.each do |user|
      throw "Impossible to update policy for user #{user.id}" unless user.update_policies(Users::Policy.policies.keys)
    end
  end

  task users_remove_policies: :environment do
    User.all.each do |user|
      user.users_policies.destroy_all
    end
  end
end
