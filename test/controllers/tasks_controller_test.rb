# frozen_string_literal: true

require "test_helper"

class TasksControllerTest < ActionController::TestCase
  tests TasksController

  def setup
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Test GET index with valid policy
  test "should get index" do
    @user.users_policies.create!(policy: "tasks_index")
    get :index
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@tasks_per_date)
  end
end
