# frozen_string_literal: true

require "test_helper"

class ProjectsControllerTest < ActionController::TestCase
  tests ProjectsController

  def setup
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Test for GET index with valid policy
  test "should get index with valid policy" do
    @user.users_policies.create!(policy: "projects_index")
    get :index
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@projects)
    assert_not_nil @controller.instance_variable_get(:@projects_preferred)
  end

  # Test for GET index without valid policy
  test "should not get index without valid policy" do
    get :index
    assert_redirected_to root_path
  end

  # Test for GET show with valid policy
  test "should get show with valid policy" do
    @user.users_policies.create!(policy: "projects_show")
    project = projects(:one)
    get :show, params: { id: project.id }
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@project)
  end

  # Test for GET show without valid policy
  test "should not get show without valid policy" do
    project = projects(:one)
    get :show, params: { id: project.id }
    assert_redirected_to root_path
  end
end
