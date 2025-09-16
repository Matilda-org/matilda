# frozen_string_literal: true

require "test_helper"

class CredentialsControllerTest < ActionController::TestCase
  tests CredentialsController

  def setup
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Tests for GET index with valid policy
  test "should get index with valid policy" do
    @user.users_policies.create!(policy: "credentials_index")
    get :index
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@credentials)
    assert_not_nil @controller.instance_variable_get(:@credentials_preferred)
  end

  # Tests for GET index without valid policy
  test "should not get index without valid policy" do
    get :index
    assert_redirected_to root_path
  end

  # Tests for GET actions with type create
  test "should get actions create" do
    get :actions, params: { type: "create" }
    assert_response :success
    assert_match(/Nuova credenziale/, @response.body)
  end

  # Tests for GET actions with type edit and valid id
  test "should get actions edit with valid id" do
    credential = credentials(:one)
    get :actions, params: { type: "edit", id: credential.id }
    assert_response :success
    assert_match(/Modifica credenziale/, @response.body)
  end

  # Tests for GET actions with type edit and invalid id
  test "should get actions edit with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "edit", id: 9999 }
    end
  end

  # Tests for GET actions with type destroy and valid id
  test "should get actions destroy with valid id" do
    get :actions, params: { type: "destroy", id: credentials(:one).id }
    assert_response :success
    assert_match(/Elimina credenziale/, @response.body)
  end

  # Tests for GET actions with type destroy and invalid id
  test "should get actions destroy with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "destroy", id: 9999 }
    end
  end

  # Tests for GET actions with type show and valid id
  test "should get actions show with valid id" do
    credential = credentials(:one)
    get :actions, params: { type: "show", id: credential.id }
    assert_response :success
    assert_match(/Visualizza credenziale/, @response.body)
  end

  # Tests for GET actions with type show and invalid id
  test "should get actions show with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "show", id: 9999 }
    end
  end

  # Tests for GET actions with invalid type
  test "should not get actions with invalid type" do
    get :actions, params: { type: "invalid_type" }
    assert_response :success
    assert_match(/Errore/, @response.body)
  end

  # Tests for POST set_phrase_action with valid policy and valid params
  test "should post set_phrase_action with valid params and valid policy" do
    @user.users_policies.create!(policy: "credentials_set_phrase")
    post :set_phrase_action, params: { phrase: { phrase: "new_passphrase" } }
    assert_response :success
    assert_match(/Password di criptazione impostata/, @response.body)
  end

  # Tests for POST set_phrase_action without valid policy
  test "should not post set_phrase_action without valid policy" do
    post :set_phrase_action, params: { phrase: { phrase: "new_passphrase" } }
    assert_redirected_to root_path
  end

  # Tests for POST create_action with valid policy and valid params
  test "should post create_action with valid params and valid policy" do
    @user.users_policies.create!(policy: "credentials_create")
    post :create_action, params: { name: "New Credential", secure_username: "new_user", secure_password: "new_pass", secure_content: "new_content" }
    assert_response :success
    assert_match(/Credenziale salvata/, @response.body)
  end

  # Tests for POST create_action with valid policy and invalid params
  test "should not post create_action with invalid params and valid policy" do
    @user.users_policies.create!(policy: "credentials_create")
    post :create_action, params: { name: "", secure_username: "new_user", secure_password: "new_pass", secure_content: "new_content" }
    assert_response :success
    assert_match(/Nuova credenziale/, @response.body)
  end

  # Tests for POST create_action without valid policy
  test "should not post create_action without valid policy" do
    post :create_action, params: { name: "New Credential", secure_username: "new_user", secure_password: "new_pass", secure_content: "new_content" }
    assert_redirected_to root_path
  end

  # Tests for POST edit_action with valid policy, valid id and valid params
  test "should post edit_action with valid id, valid params and valid policy" do
    @user.users_policies.create!(policy: "credentials_edit")
    credential = credentials(:one)
    post :edit_action, params: { id: credential.id, name: "Updated Credential", secure_username: "updated_user", secure_password: "updated_pass", secure_content: "updated_content" }
    assert_response :success
    assert_match(/Credenziale salvata/, @response.body)
  end

  # # Tests for POST edit_action with valid policy, valid id and invalid params
  # test "should not post edit_action with valid id, invalid params and valid policy" do
  #   @user.users_policies.create!(policy: "credentials_edit")
  #   credential = credentials(:one)
  #   post :edit_action, params: { id: credential.id, name: "", secure_username: "updated_user", secure_password: "updated_pass", secure_content: "updated_content" }
  #   assert_response :success
  #   assert_match(/Modifica credenziale/, @response.body)
  # end

  # Tests for POST edit_action with valid policy and invalid id
  test "should not post edit_action with invalid id and valid policy" do
    @user.users_policies.create!(policy: "credentials_edit")
    post :edit_action, params: { id: 9999, name: "Updated Credential", secure_username: "updated_user", secure_password: "updated_pass", secure_content: "updated_content" }
    assert_redirected_to credentials_path
  end

  # Tests for POST edit_action without valid policy
  test "should not post edit_action without valid policy" do
    credential = credentials(:one)
    post :edit_action, params: { id: credential.id, name: "Updated Credential", secure_username: "updated_user", secure_password: "updated_pass", secure_content: "updated_content" }
    assert_redirected_to root_path
  end

  # Tests for POST destroy_action with valid policy and valid id
  test "should post destroy_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "credentials_destroy")
    credential = credentials(:one)
    post :destroy_action, params: { id: credential.id }
    assert_response :success
    assert_match(/Credenziale eliminata/, @response.body)
  end

  # Tests for POST destroy_action with valid policy and invalid id
  test "should not post destroy_action with invalid id and valid policy" do
    @user.users_policies.create!(policy: "credentials_destroy")
    post :destroy_action, params: { id: 9999 }
    assert_redirected_to credentials_path
  end

  # Tests for POST destroy_action without valid policy
  test "should not post destroy_action without valid policy" do
    credential = credentials(:one)
    post :destroy_action, params: { id: credential.id }
    assert_redirected_to root_path
  end
end
