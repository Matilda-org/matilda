# frozen_string_literal: true

require "test_helper"

class ToolsControllerTest < ActionController::TestCase
  tests ToolsController

  def setup
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Test GET index
  test "should get index" do
    @user.users_policies.create!(policy: "tools")
    get :index
    assert_response :success
  end
end
