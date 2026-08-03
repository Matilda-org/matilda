require "test_helper"

class Projects::RepositoryTest < ActiveSupport::TestCase
  test "normalizes the url and detects the name" do
    project = projects(:one)

    repository = project.projects_repositories.create!(url: "git@gitlab.com:group/subgroup/repo.git", provider: :gitlab)
    assert_equal "https://gitlab.com/group/subgroup/repo", repository.url
    assert_equal "group/subgroup/repo", repository.name

    repository = project.projects_repositories.create!(url: "github.com/owner/repo/", provider: :github)
    assert_equal "https://github.com/owner/repo", repository.url
    assert_equal "owner/repo", repository.name
  end

  # The provider is chosen in the form (autofilled from the url by the Stimulus controller), never inferred here.
  test "keeps the given provider whatever the host is" do
    repository = projects(:one).projects_repositories.create!(url: "https://github.com/owner/repo", provider: :gitlab)
    assert_equal "gitlab", repository.provider
  end

  test "rejects a missing provider" do
    repository = projects(:one).projects_repositories.new(url: "https://github.com/owner/repo")
    assert_not repository.valid?
    assert repository.errors[:provider].any?
  end

  test "rejects urls without a repository path" do
    repository = projects(:one).projects_repositories.new(url: "https://github.com", provider: :github)
    assert_not repository.valid?
    assert repository.errors[:url].any?
  end

  test "rejects the same repository twice on the same project" do
    project = projects(:one)
    project.projects_repositories.create!(url: "https://github.com/owner/repo", provider: :github)

    duplicate = project.projects_repositories.new(url: "git@github.com:owner/repo.git", provider: :github)
    assert_not duplicate.valid?
    assert duplicate.errors[:url].any?
  end

  test "saves an event on the project on creation" do
    project = projects(:one)

    assert_difference -> { project.projects_events.count }, 1 do
      project.projects_repositories.create!(url: "https://github.com/owner/repo", provider: :github)
    end
  end

  # Without this the project page keeps serving the action cached html
  # and the repository looks missing even if it is stored.
  test "clears the views cache on create and destroy" do
    Rails.cache.write("views/some-fragment", "cached")
    repository = projects(:one).projects_repositories.create!(url: "https://github.com/owner/repo", provider: :github)
    assert_nil Rails.cache.read("views/some-fragment")

    Rails.cache.write("views/some-fragment", "cached")
    repository.destroy!
    assert_nil Rails.cache.read("views/some-fragment")
  end
end
