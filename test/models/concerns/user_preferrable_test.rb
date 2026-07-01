require "test_helper"

class UserPreferrableTest < ActiveSupport::TestCase
  setup { Rails.cache.clear }

  test "user_prefer? returns true when the user prefers the resource" do
    user = users(:one)
    project = projects(:one)
    project.users_prefers.create!(user_id: user.id)

    assert project.user_prefer?(user)
  end

  test "user_prefer? returns false when the user does not prefer the resource" do
    user = users(:one)
    project = projects(:one)

    assert_not project.user_prefer?(user)
  end

  test "user_prefer? accepts a user id instead of a User instance" do
    user = users(:one)
    project = projects(:one)
    project.users_prefers.create!(user_id: user.id)

    assert project.user_prefer?(user.id)
  end

  test "user_preferred scope returns only resources preferred by the given user" do
    user = users(:one)
    preferred_project = projects(:one)
    preferred_project.users_prefers.create!(user_id: user.id)

    assert_includes Project.user_preferred(user.id), preferred_project
  end
end
