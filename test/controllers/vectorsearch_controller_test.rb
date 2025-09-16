# frozen_string_literal: true

require "test_helper"

class VectorsearchControllerTest < ActionController::TestCase
  tests VectorsearchController

  def setup
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Test GET index with valid policy
  test "should get chat" do
    get :chat
    assert_response :success
  end
end
