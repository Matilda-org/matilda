# frozen_string_literal: true

require "test_helper"

class UsersControllerTest < ActionController::TestCase
  tests UsersController

  def setup
    setup_controller_test
  end

  # Test GET index with valid policy
  test "should get index" do
    @user.users_policies.create!(policy: "users_index")
    get :index
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@users)
  end
end
