# frozen_string_literal: true

require "test_helper"

class VectorsearchControllerTest < ActionController::TestCase
  tests VectorsearchController

  def setup
    setup_controller_test
  end

  # Test GET index with valid policy
  test "should get chat" do
    get :chat
    assert_response :success
  end
end
