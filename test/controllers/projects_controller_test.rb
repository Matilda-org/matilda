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
end
