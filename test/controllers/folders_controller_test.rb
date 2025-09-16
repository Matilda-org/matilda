# frozen_string_literal: true

require "test_helper"

class FoldersControllerTest < ActionController::TestCase
  tests FoldersController

  def setup
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Tests for GET show
  test "should get show" do
    folder = folders(:one)
    get :show, params: { id: folder.id }
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@folder)
    assert_not_nil @controller.instance_variable_get(:@projects)
    assert_not_nil @controller.instance_variable_get(:@credentials)
  end

  # Tests for GET actions with type create
  test "should get actions create" do
    get :actions, params: { type: "create" }
    assert_response :success
    assert_match(/Nuova cartella/, @response.body)
  end

  # Tests for GET actions with type edit and valid id
  test "should get actions edit with valid id" do
    folder = folders(:one)
    get :actions, params: { type: "edit", id: folder.id }
    assert_response :success
    assert_match(/Modifica cartella/, @response.body)
  end

  # Tests for GET actions with type edit and invalid id
  test "should get actions edit with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "edit", id: 9999 }
    end
  end

  # Tests for GET actions with type destroy and valid id
  test "should get actions destroy with valid id" do
    get :actions, params: { type: "destroy", id: folders(:one).id }
    assert_response :success
    assert_match(/Elimina cartella/, @response.body)
  end

  # Tests for GET actions with type destroy and invalid id
  test "should get actions destroy with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "destroy", id: 9999 }
    end
  end

  # Tests for GET actions with invalid type
  test "should get actions with invalid type" do
    get :actions, params: { type: "invalid_type" }
    assert_response :success
    assert_match(/Si è verificato un errore/, @response.body)
  end

  # Tests for POST create_action with valid policy and valid params
  test "should post create_action with valid params and valid policy" do
    @user.users_policies.create!(policy: "folders_create")
    post :create_action, params: { name: "New Folder" }
    assert_response :success
    assert_match(/Cartella creata/, @response.body)
    assert Folder.exists?(name: "New Folder")
  end

  # Tests for POST create_action without valid policy
  test "should not post create_action without valid policy" do
    post :create_action, params: { name: "New Folder" }
    assert_redirected_to root_path
  end

  # Tests for POST edit_action with valid policy and valid params
  test "should post edit_action with valid params and valid policy" do
    @user.users_policies.create!(policy: "folders_edit")
    folder = folders(:one)
    post :edit_action, params: { id: folder.id, name: "Updated Folder" }
    assert_response :success
    assert_match(/Cartella aggiornata/, @response.body)
    folder.reload
    assert_equal "Updated Folder", folder.name
  end

  # Tests for POST edit_action with valid policy and invalid id
  test "should not post edit_action with invalid id even with valid policy" do
    @user.users_policies.create!(policy: "folders_edit")
    post :edit_action, params: { id: 9999, name: "Updated Folder" }
    assert_redirected_to root_path
  end

  # Tests for POST edit_action without valid policy
  test "should not post edit_action without valid policy" do
    folder = folders(:one)
    post :edit_action, params: { id: folder.id, name: "Updated Folder" }
    assert_redirected_to root_path
  end

  # Tests for POST destroy_action with valid policy and valid params
  test "should post destroy_action with valid params and valid policy" do
    @user.users_policies.create!(policy: "folders_destroy")
    folder = folders(:one)
    post :destroy_action, params: { id: folder.id }
    assert_response :success
    assert_match(/Cartella eliminata/, @response.body)
    assert_not Folder.exists?(folder.id)
  end

  # Tests for POST destroy_action with valid policy and invalid id
  test "should not post destroy_action with invalid id even with valid policy" do
    @user.users_policies.create!(policy: "folders_destroy")
    post :destroy_action, params: { id: 9999 }
    assert_redirected_to root_path
  end

  # Tests for POST destroy_action without valid policy
  test "should not post destroy_action without valid policy" do
    folder = folders(:one)
    post :destroy_action, params: { id: folder.id }
    assert_redirected_to root_path
    assert Folder.exists?(folder.id)
  end

  # Tests for POST manage_resource_action with valid policy
  test "should post manage_resource_action with valid policy" do
    @user.users_policies.create!(policy: "folders_manage_resources")
    folder = folders(:one)
    post :manage_resource_action, params: { folder_id: folder.id, resource_type: "Project", resource_id: projects(:one).id }
    assert_response :success
    assert_match(/Cartella aggiornata/, @response.body)
    folder.reload
    assert folder.projects.exists?(projects(:one).id)
  end
end
