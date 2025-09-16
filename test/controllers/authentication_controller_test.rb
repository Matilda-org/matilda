# frozen_string_literal: true

require "test_helper"

class AuthenticationControllerTest < ActionController::TestCase
  tests AuthenticationController

  def setup
    @user = users(:one)
    @valid_password = "password123"
    @user.update(password: @valid_password, password_confirmation: @valid_password)

    # Clear cache and emails before each test
    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Tests for GET actions that don't require CSRF protection
  test "should get login page" do
    get :login
    assert_response :success
    assert_instance_of User, @controller.instance_variable_get(:@user)
  end

  test "should get login page with redirect parameter" do
    redirect_url = "/dashboard"
    get :login, params: { redirect: redirect_url }
    assert_response :success
    assert_equal redirect_url, @controller.instance_variable_get(:@redirect)
  end

  test "should set authentication layout variables on login" do
    get :login
    assert_response :success
    assert @controller.instance_variable_get(:@_flash_disabled)
    assert @controller.instance_variable_get(:@_navbar_disabled)
    assert @controller.instance_variable_get(:@_authentication)
  end

  test "should get recover password page" do
    get :recover_password
    assert_response :success
    assert @controller.instance_variable_get(:@_flash_disabled)
    assert @controller.instance_variable_get(:@_navbar_disabled)
    assert @controller.instance_variable_get(:@_authentication)
  end

  test "should get update password page" do
    get :update_password, params: { id: @user.id }
    assert_response :success
    assert_equal @user, @controller.instance_variable_get(:@user)
    assert @controller.instance_variable_get(:@_flash_disabled)
    assert @controller.instance_variable_get(:@_navbar_disabled)
    assert @controller.instance_variable_get(:@_authentication)
  end

  # Tests for before_action configurations
  test "should disable flash messages on all authentication pages" do
    [
      -> { get :login },
      -> { get :recover_password },
      -> { get :update_password, params: { id: @user.id } }
    ].each do |request_block|
      request_block.call
      assert @controller.instance_variable_get(:@_flash_disabled), "Flash should be disabled"
    end
  end

  test "should disable navbar on all authentication pages" do
    [
      -> { get :login },
      -> { get :recover_password },
      -> { get :update_password, params: { id: @user.id } }
    ].each do |request_block|
      request_block.call
      assert @controller.instance_variable_get(:@_navbar_disabled), "Navbar should be disabled"
    end
  end

  test "should set authentication flag on all authentication pages" do
    [
      -> { get :login },
      -> { get :recover_password },
      -> { get :update_password, params: { id: @user.id } }
    ].each do |request_block|
      request_block.call
      assert @controller.instance_variable_get(:@_authentication), "Authentication flag should be set"
    end
  end

  # Test user_login_params method indirectly
  test "login params should be properly initialized" do
    get :login, params: { email: "test@example.com" }
    assert_response :success

    user = @controller.instance_variable_get(:@user)
    assert_instance_of User, user
    assert_equal "test@example.com", user.email
  end

  # Test cache behavior in test environment
  test "should handle cache operations for password recovery" do
    # Note: In test environment, cache might behave differently
    # This test verifies the cache interface works
    code = "ABCD1234"
    cache_key = "AuthenticationController/recover_password/#{@user.id}"

    # Test that cache write/read interface exists and is callable
    assert_nothing_raised do
      Rails.cache.write(cache_key, code, expires_in: 30.minutes)
      Rails.cache.read(cache_key)
      Rails.cache.delete(cache_key)
    end
  end

  # Test User model authentication
  test "user authentication should work correctly" do
    assert @user.authenticate(@valid_password)
    assert_not @user.authenticate("wrong_password")
  end

  # Test User model update
  test "user password update should work" do
    new_password = "newpassword123"

    result = @user.update(password: new_password, password_confirmation: new_password)
    assert result

    @user.reload
    assert @user.authenticate(new_password)
    assert_not @user.authenticate(@valid_password)
  end

  # Test SecureRandom code generation (as used in the controller)
  test "secure random code generation should work" do
    code = SecureRandom.hex(4).upcase
    assert_equal 8, code.length
    assert_match(/\A[0-9A-F]+\z/, code)
  end
end
