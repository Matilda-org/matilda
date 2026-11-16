# frozen_string_literal: true

require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  test "requires login" do
    get search_path(q: "Task")

    assert_redirected_to authentication_login_path(redirect: search_path)
  end

  test "returns grouped results with a link to the full search" do
    sign_in_as(@user)

    get search_path(q: "task one")

    assert_response :success
    assert_includes @response.body, 'id="global-search-results"'
    assert_includes @response.body, "global-search-option-tasks-#{tasks(:one).id}"
    assert_includes @response.body, "Vedi tutti i risultati"
    assert_includes @response.body, users_show_path(@user, search: "task one")
  end

  test "asks for more characters below the minimum length" do
    sign_in_as(@user)

    get search_path(q: "ta")

    assert_response :success
    assert_includes @response.body, "Digita almeno 3 caratteri"
    assert_not_includes @response.body, tasks(:one).title
  end

  test "members-only users don't find tasks of other projects" do
    tasks(:one).update_columns(project_id: projects(:one).id, user_id: users(:two).id)
    grant(@user, "only_data_projects_as_member")
    sign_in_as(@user)

    get search_path(q: tasks(:one).title)

    assert_response :success
    assert_not_includes @response.body, "global-search-option-tasks-#{tasks(:one).id}"
  end

  test "credentials need the credentials policy" do
    sign_in_as(@user)
    get search_path(q: credentials(:one).name)
    assert_not_includes @response.body, "global-search-option-credentials-#{credentials(:one).id}"

    grant(@user, "credentials_index")
    get search_path(q: credentials(:one).name)
    assert_includes @response.body, "global-search-option-credentials-#{credentials(:one).id}"
  end

  private

  def sign_in_as(user)
    post authentication_login_action_path, params: { email: user.email, password: "password123" }
  end

  def grant(user, *policies)
    policies.each { |policy| user.users_policies.create!(policy: policy) }
  end
end
