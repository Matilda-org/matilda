namespace :helpers do
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
