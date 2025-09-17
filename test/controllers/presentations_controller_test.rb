# frozen_string_literal: true

require "test_helper"

class PresentationsControllerTest < ActionController::TestCase
  tests PresentationsController

  def setup
    setup_controller_test
  end

  # Test GET index with valid policy
  test "should get index with valid policy" do
    @user.users_policies.create!(policy: "presentations_index")
    get :index
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@presentations)
  end

  # Test GET index without valid policy
  test "should not get index without valid policy" do
    get :index
    assert_redirected_to root_path
  end
end
