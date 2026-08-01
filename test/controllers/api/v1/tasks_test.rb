# frozen_string_literal: true

require "test_helper"

class Api::V1::TasksTest < ApiIntegrationTest
  test "index requires api key and tasks_index policy" do
    assert_requires_api_key :get, "/api/v1/tasks"
    assert_requires_policy :get, "/api/v1/tasks", "tasks_index"
  end

  test "index filters tasks" do
    give_policy "tasks_index"

    get "/api/v1/tasks", params: { completed: "true" }, headers: api_headers
    titles = json_response["data"].map { |t| t["title"] }
    assert_includes titles, tasks(:two).title
    assert_not_includes titles, tasks(:one).title

    get "/api/v1/tasks", params: { deadline_from: Date.today.to_s }, headers: api_headers
    titles = json_response["data"].map { |t| t["title"] }
    assert_includes titles, tasks(:one).title
    assert_not_includes titles, tasks(:two).title

    get "/api/v1/tasks", params: { deadline_from: "not-a-date" }, headers: api_headers
    assert_response :bad_request
  end

  test "index respects only_data_projects_as_member policy" do
    other_project = Project.create!(code: "other", name: "Other project", year: 2026)
    hidden = Task.create!(title: "Hidden task", project: other_project, user: users(:two))
    mine = Task.create!(title: "Assigned to me", user: @user)

    give_policy "tasks_index"
    give_policy "only_data_projects_as_member"
    Projects::Member.create!(project: projects(:one), user: @user, role: "Dev")
    visible = Task.create!(title: "Project task", project: projects(:one))

    get "/api/v1/tasks", headers: api_headers
    titles = json_response["data"].map { |t| t["title"] }
    assert_includes titles, visible.title
    assert_includes titles, mine.title
    assert_not_includes titles, hidden.title
  end

  test "show requires tasks_show policy and includes relations and content" do
    task = tasks(:one)
    task.update!(content: "<p>Details</p>")
    assert_requires_policy :get, "/api/v1/tasks/#{task.id}", "tasks_show"

    body = json_response
    assert_equal task.id, body["id"]
    assert body.key?("tasks_comments")
    assert_includes body["content"].to_s, "Details"
  end

  test "create requires tasks_create policy and creates the task" do
    assert_requires_policy :post, "/api/v1/tasks", "tasks_create",
      params: { title: "New API task", deadline: Date.today.to_s, user_id: @user.id },
      success_status: :created

    body = json_response
    assert_equal "New API task", body["title"]
    assert Task.exists?(body["id"])
  end

  test "create returns validation errors" do
    give_policy "tasks_create"
    post "/api/v1/tasks", params: { title: "" }, headers: api_headers, as: :json
    assert_response :unprocessable_content
    assert json_response["errors"].any?
  end

  test "update requires tasks_edit policy and updates the task" do
    task = tasks(:one)
    assert_requires_policy :patch, "/api/v1/tasks/#{task.id}", "tasks_edit",
      params: { title: "Updated title" }

    assert_equal "Updated title", task.reload.title
  end

  test "destroy requires tasks_destroy policy and deletes the task" do
    task = Task.create!(title: "To delete")
    assert_requires_policy :delete, "/api/v1/tasks/#{task.id}", "tasks_destroy",
      success_status: :no_content

    assert_not Task.exists?(task.id)
  end

  test "complete and uncomplete toggle the task state" do
    task = tasks(:one)
    give_policy "tasks_complete"
    give_policy "tasks_uncomplete"

    post "/api/v1/tasks/#{task.id}/complete", headers: api_headers
    assert_response :success
    assert task.reload.completed

    post "/api/v1/tasks/#{task.id}/uncomplete", headers: api_headers
    assert_response :success
    assert_not task.reload.completed
  end

  test "comments requires tasks_comment policy and attributes the comment to the api user" do
    task = tasks(:one)
    assert_requires_policy :post, "/api/v1/tasks/#{task.id}/comments", "tasks_comment",
      params: { content: "A comment" },
      success_status: :created

    comment = task.tasks_comments.last
    assert_equal "A comment", comment.content
    assert_equal @user.id, comment.user_id
  end

  test "comments strip CDATA wrappers sent by API clients" do
    task = tasks(:one)
    give_policy "tasks_comment"
    post "/api/v1/tasks/#{task.id}/comments",
      params: { content: "<![CDATA[**Markdown** body]]>" }, headers: api_headers
    assert_response :created
    assert_equal "**Markdown** body", task.tasks_comments.last.content
  end

  test "limited users cannot touch tasks outside their projects" do
    other_project = Project.create!(code: "other", name: "Other project", year: 2026)
    hidden = Task.create!(title: "Hidden task", project: other_project, user: users(:two))

    give_policy "tasks_edit"
    give_policy "only_data_projects_as_member"

    patch "/api/v1/tasks/#{hidden.id}", params: { title: "Hacked" }, headers: api_headers, as: :json
    assert_response :not_found
    assert_equal "Hidden task", hidden.reload.title
  end
end
