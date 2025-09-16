# frozen_string_literal: true

require "test_helper"

class ProceduresControllerTest < ActionController::TestCase
  tests ProceduresController

  def setup
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Tests for GET index with valid policy
  test "should get index with valid policy" do
    @user.users_policies.create!(policy: "procedures_index")
    get :index
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@procedures)
    assert_not_nil @controller.instance_variable_get(:@procedures_preferred)
  end

  # Tests for GET index without valid policy
  test "should get index without valid policy" do
    get :index
    assert_redirected_to root_path
  end

  # Tests for GET show with valid policy
  test "should get show with valid policy" do
    @user.users_policies.create!(policy: "procedures_show")
    procedure = procedures(:one)
    get :show, params: { id: procedure.id }
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@procedure)
  end

  # Tests for GET show without valid policy
  test "should not get show without valid policy" do
    procedure = procedures(:one)
    get :show, params: { id: procedure.id }
    assert_redirected_to root_path
  end

  # Tests for GET actions with type create
  test "should get actions create" do
    get :actions, params: { type: "create" }
    assert_response :success
    assert_match(/Nuova board/, @response.body)
  end

  # Tests for GET actions with type edit and valid id
  test "should get actions edit with valid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "edit", id: procedure.id }
    assert_response :success
    assert_match(/Modifica board/, @response.body)
  end

  # Tests for GET actions with type edit and invalid id
  test "should get actions edit with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "edit", id: 9999 }
    end
  end

  # Tests for GET actions with type archive and valid id
  test "should get actions archive with valid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "archive", id: procedure.id }
    assert_response :success
    assert_match(/Archivia board/, @response.body)
  end

  # Tests for GET actions with type archive and invalid id
  test "should get actions archive with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "archive", id: 9999 }
    end
  end

  # Tests for GET actions with type unarchive and valid id
  test "should get actions unarchive with valid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "unarchive", id: procedure.id }
    assert_response :success
    assert_match(/Ri-attiva board/, @response.body)
  end

  # Tests for GET actions with type unarchive and invalid id
  test "should get actions unarchive with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "unarchive", id: 9999 }
    end
  end

  # Tests for GET actions with type clone and valid id
  test "should get actions clone with valid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "clone", id: procedure.id }
    assert_response :success
    assert_match(/Clona board/, @response.body)
  end

  # Tests for GET actions with type clone and invalid id
  test "should get actions clone with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "clone", id: 9999 }
    end
  end

  # Tests for GET actions with type add-status and valid id
  test "should get actions add-status with valid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "add-status", id: procedure.id }
    assert_response :success
    assert_match(/Aggiungi stato/, @response.body)
  end

  # Tests for GET actions with type add-status and invalid id
  test "should get actions add-status with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "add-status", id: 9999 }
    end
  end

  # Tests for GET actions with type destroy and valid id
  test "should get actions destroy with valid id" do
    get :actions, params: { type: "destroy", id: procedures(:one).id }
    assert_response :success
    assert_match(/Elimina board/, @response.body)
  end

  # Tests for GET actions with type destroy and invalid id
  test "should get actions destroy with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "destroy", id: 9999 }
    end
  end
end
