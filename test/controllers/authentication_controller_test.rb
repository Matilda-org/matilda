# frozen_string_literal: true

require "test_helper"

class AuthenticationControllerTest < ActionController::TestCase
  tests AuthenticationController

  def setup
    setup_controller_test
    cookies.encrypted[:user_id] = nil # Force not logged in on setup
  end

  # Tests for GET login
  test "should get login page" do
    get :login
    assert_response :success
    assert_instance_of User, @controller.instance_variable_get(:@user)
  end

  # Tests for POST login_action with valid credentials
  test "should login with valid credentials" do
    post :login_action, params: { email: @user.email, password: "password123" }

    assert_redirected_to root_path
    assert_equal @user.id, cookies.encrypted[:user_id]
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  # Tests for POST login_action with invalid credentials
  test "should not login with invalid credentials" do
    post :login_action, params: { email: @user.email, password: "wrongpassword" }

    assert_redirected_to authentication_login_path(email: @user.email)
    assert_nil cookies.encrypted[:user_id]
  end

  # Tests for GET recover_password
  test "should get recover password page" do
    get :recover_password
    assert_response :success
  end

  # Tests for POST recover_password_action with valid email
  test "should send recover password email with valid email" do
    post :recover_password_action, params: { email: @user.email }

    assert_response :redirect
    token = @response.redirect_url.split("/").last
    assert_redirected_to authentication_update_password_path(token)
    assert_not_includes @response.redirect_url, "/#{@user.id}"
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal @user.id, Rails.cache.read("AuthenticationController/recover_password/#{token}")[:user_id]
  end

  # Unknown emails get the same answer, so accounts can't be enumerated
  test "should answer the same way with invalid email" do
    post :recover_password_action, params: { email: "invalid@example.com" }

    assert_response :redirect
    assert_match %r{/authentication/update-password/}, @response.redirect_url
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  # Tests for GET update_password
  test "should get update password page" do
    get :update_password, params: { id: "token" }
    assert_response :success
  end

  # Tests for POST update_password_action with valid code and matching passwords
  test "should update password with valid code and matching passwords" do
    code = write_recovery_code
    old_version = @user.session_version

    post :update_password_action, params: { id: "token", code: code, password: "newpassword123", password_confirmation: "newpassword123" }
    assert_redirected_to authentication_login_path
    assert @user.reload.authenticate("newpassword123")
    assert_equal old_version + 1, @user.session_version
    assert_nil Rails.cache.read("AuthenticationController/recover_password/token")
  end

  # Tests for POST update_password_action with invalid code
  test "should not update password with invalid code" do
    write_recovery_code

    post :update_password_action, params: { id: "token", code: "WRONGCODE", password: "newpassword123", password_confirmation: "newpassword123" }
    assert_redirected_to authentication_update_password_path("token")
    assert @user.reload.authenticate("password123")
  end

  test "should not update password with unknown token" do
    post :update_password_action, params: { id: "missing", code: "ANY", password: "newpassword123", password_confirmation: "newpassword123" }
    assert_redirected_to authentication_update_password_path("missing")
    assert @user.reload.authenticate("password123")
  end

  # Tests for POST update_password_action with non-matching passwords
  test "should not update password with non-matching passwords" do
    code = write_recovery_code

    post :update_password_action, params: { id: "token", code: code, password: "newpassword123", password_confirmation: "differentpassword123" }
    assert_redirected_to authentication_update_password_path("token")
    assert @user.reload.authenticate("password123")
  end

  # Tests for GET logout
  test "should logout user" do
    cookies.encrypted[:user_id] = @user.id
    get :logout

    assert_redirected_to root_path
    assert_nil cookies.encrypted[:user_id]
  end

  test "login ignores redirects to other hosts" do
    post :login_action, params: { email: @user.email, password: "password123", redirect: "https://evil.example.com" }
    assert_redirected_to root_path
  end

  private

  def write_recovery_code
    code = SecureRandom.hex(4).upcase
    Rails.cache.write("AuthenticationController/recover_password/token", { user_id: @user.id, code: code })
    code
  end
end
