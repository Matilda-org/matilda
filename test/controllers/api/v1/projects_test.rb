# frozen_string_literal: true

require "test_helper"

class Api::V1::ProjectsTest < ApiIntegrationTest
  test "index requires api key and projects_index policy" do
    assert_requires_api_key :get, "/api/v1/projects"
    assert_requires_policy :get, "/api/v1/projects", "projects_index"
  end

  test "index returns paginated projects and excludes archived by default" do
    archived = Project.create!(code: "arch", name: "Archived", year: 2026, archived: true)
    give_policy "projects_index"

    get "/api/v1/projects", headers: api_headers
    ids = json_response["data"].map { |p| p["id"] }
    assert_includes ids, projects(:one).id
    assert_not_includes ids, archived.id

    get "/api/v1/projects", params: { archived: true }, headers: api_headers
    ids = json_response["data"].map { |p| p["id"] }
    assert_equal [ archived.id ], ids
  end

  test "index respects only_data_projects_as_member policy" do
    other = Project.create!(code: "other", name: "Other project", year: 2026)
    give_policy "projects_index"
    give_policy "only_data_projects_as_member"
    Projects::Member.create!(project: projects(:one), user: @user, role: "Dev")

    get "/api/v1/projects", headers: api_headers
    ids = json_response["data"].map { |p| p["id"] }
    assert_equal [ projects(:one).id ], ids
    assert_not_includes ids, other.id
  end

  test "create requires projects_create policy and creates the project" do
    assert_requires_policy :post, "/api/v1/projects", "projects_create",
      params: { code: "crew-prj", name: "Crew project" },
      success_status: :created

    project = Project.find_by(code: "CREW-PRJ") # code is upcased on create
    assert_equal "Crew project", project.name
    assert_equal Date.today.year, project.year
  end

  test "create returns validation errors" do
    give_policy "projects_create"
    post "/api/v1/projects", params: { code: "" }, headers: api_headers
    assert_response :unprocessable_content
    assert json_response["errors"].any?
  end

  test "show requires projects_show policy and includes relations" do
    assert_requires_policy :get, "/api/v1/projects/#{projects(:one).id}", "projects_show"

    body = json_response
    assert_equal projects(:one).id, body["id"]
    assert body.key?("projects_members")
  end

  test "show returns 404 for projects outside membership scope" do
    other = Project.create!(code: "other", name: "Other project", year: 2026)
    give_policy "projects_show"
    give_policy "only_data_projects_as_member"
    Projects::Member.create!(project: projects(:one), user: @user, role: "Dev")

    get "/api/v1/projects/#{other.id}", headers: api_headers
    assert_response :not_found
  end

  test "logs returns paginated project logs" do
    log = projects(:one).projects_logs.create!(user: @user, title: "A log entry", date: Date.today)
    give_policy "projects_show"

    get "/api/v1/projects/#{projects(:one).id}/logs", headers: api_headers
    assert_response :success
    assert_equal projects(:one).projects_logs.count, json_response["meta"]["total_count"]
    assert_includes json_response["data"].map { |l| l["id"] }, log.id
  end
end
