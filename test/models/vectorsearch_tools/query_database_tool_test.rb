require "test_helper"

class VectorsearchTools::QueryDatabaseToolTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @member_project = Project.create!(code: "MEM", name: "Member Project", year: 2026)
    @other_project = Project.create!(code: "OTH", name: "Other Project", year: 2026)
  end

  # user two, member of @member_project only, restricted to member projects
  def restricted_user
    user = users(:two)
    @member_project.projects_members.create!(user_id: user.id, role: "member")
    user.update_policies([ "only_data_projects_as_member" ])
    user
  end

  test "unrestricted user sees every project" do
    result = VectorsearchTools::QueryDatabaseTool.new(users(:one)).prjs({})

    assert_includes result, "Member Project"
    assert_includes result, "Other Project"
  end

  test "member-restricted user only sees their own projects" do
    result = VectorsearchTools::QueryDatabaseTool.new(restricted_user).prjs({})

    assert_includes result, "Member Project"
    assert_not_includes result, "Other Project"
  end

  test "member-restricted user cannot read tasks of other projects" do
    Task.create!(title: "Mine", project: @member_project)
    Task.create!(title: "Hidden", project: @other_project)

    result = VectorsearchTools::QueryDatabaseTool.new(restricted_user).tasks({})

    assert_includes result, "Mine"
    assert_not_includes result, "Hidden"
  end

  test "member-restricted user cannot read notes of another project" do
    log = @other_project.projects_logs.create!(title: "Secret", date: Date.today, content: "top secret", user: users(:one))

    tool = VectorsearchTools::QueryDatabaseTool.new(restricted_user)

    assert_equal "Nota non trovata", tool.prjs_log_content({ projects_log_id: log.id })
  end

  test "credentials tool is blocked without the credentials policy" do
    result = VectorsearchTools::QueryDatabaseTool.new(restricted_user).credentials({})

    assert_match "Non hai i permessi", result
  end

  test "credentials tool is allowed with the credentials policy" do
    user = users(:one)
    user.update_policies([ "credentials_index" ])
    Credential.create!(name: "GitHub")

    result = VectorsearchTools::QueryDatabaseTool.new(user).credentials({})

    assert_includes result, "GitHub"
  end
end
