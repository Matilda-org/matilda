# frozen_string_literal: true

require "test_helper"

# Access rules that once leaked data: each test pins one of them down.
class SecurityRegressionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  test "credential secrets need the credentials policy" do
    sign_in_as(@user)

    get credentials_actions_id_path(type: "show", id: credentials(:one).id)

    assert_redirected_to root_path
  end

  test "members-only users can't open tasks of other projects" do
    project = projects(:one)
    task = tasks(:one)
    task.update_columns(project_id: project.id, user_id: nil)
    grant(@user, "tasks_show", "only_data_projects_as_member")
    sign_in_as(@user)

    get tasks_show_path(task)
    assert_redirected_to tasks_path

    get tasks_actions_id_path(type: "show", id: task.id)
    assert_response :not_found
  end

  test "project logs are not readable without a share code" do
    log = projects(:one).projects_logs.create!(title: "Secret", date: Date.today, content: "Secret", user_id: @user.id)

    get projects_show_log_path(log)
    assert_redirected_to authentication_login_path

    log.update!(share_code: "abc123")
    get projects_show_log_path(log, share_code: "wrong")
    assert_redirected_to authentication_login_path

    get projects_show_log_path(log, share_code: "abc123")
    assert_response :success
  end

  test "a password change signs out existing sessions" do
    grant(@user, "users_index")
    sign_in_as(@user)
    get users_path
    assert_response :success

    @user.update!(password: "anotherpassword1", password_confirmation: "anotherpassword1")

    get users_path
    assert_redirected_to authentication_login_path(redirect: users_path)
  end

  test "dashboard search hides credentials without the credentials policy" do
    sign_in_as(@user)

    get users_show_path(@user, search: credentials(:one).name.first(4))

    assert_response :success
    assert_not_includes @response.body, credentials(:one).name
  end

  test "names are escaped in cards" do
    projects(:one).update_columns(name: "<img src=x onerror=alert(1)>")
    grant(@user, "projects_index")
    sign_in_as(@user)

    get projects_path

    assert_not_includes @response.body, "<img src=x onerror=alert(1)>"
    assert_includes @response.body, "&lt;img src=x onerror=alert(1)&gt;"
  end

  private

  def sign_in_as(user)
    post authentication_login_action_path, params: { email: user.email, password: "password123" }
  end

  def grant(user, *policies)
    policies.each { |policy| user.users_policies.create!(policy: policy) }
  end
end
