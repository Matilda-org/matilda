require "test_helper"

class Projects::RepositoryTest < ActiveSupport::TestCase
  test "normalizes the url and detects provider and name" do
    project = projects(:one)

    repository = project.projects_repositories.create!(url: "git@gitlab.com:group/subgroup/repo.git")
    assert_equal "https://gitlab.com/group/subgroup/repo", repository.url
    assert_equal "gitlab", repository.provider
    assert_equal "group/subgroup/repo", repository.name

    repository = project.projects_repositories.create!(url: "github.com/owner/repo/", provider: :gitlab)
    assert_equal "https://github.com/owner/repo", repository.url
    assert_equal "github", repository.provider
    assert_equal "owner/repo", repository.name
  end

  test "keeps the given provider for self hosted instances" do
    repository = projects(:one).projects_repositories.create!(url: "https://git.example.com/owner/repo", provider: :gitlab)
    assert_equal "gitlab", repository.provider
  end

  test "rejects urls without a repository path" do
    repository = projects(:one).projects_repositories.new(url: "https://github.com")
    assert_not repository.valid?
    assert repository.errors[:url].any?
  end

  test "rejects the same repository twice on the same project" do
    project = projects(:one)
    project.projects_repositories.create!(url: "https://github.com/owner/repo")

    duplicate = project.projects_repositories.new(url: "git@github.com:owner/repo.git")
    assert_not duplicate.valid?
    assert duplicate.errors[:url].any?
  end

  test "saves an event on the project on creation" do
    project = projects(:one)

    assert_difference -> { project.projects_events.count }, 1 do
      project.projects_repositories.create!(url: "https://github.com/owner/repo")
    end
  end
end
