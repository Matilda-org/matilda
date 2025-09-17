# frozen_string_literal: true

require "test_helper"

class SettingsControllerTest < ActionController::TestCase
  tests SettingsController

  def setup
    setup_controller_test
  end

  # Test GET index
  test "should get index" do
    @user.users_policies.create!(policy: "settings")
    get :index
    assert_response :success
  end
end
