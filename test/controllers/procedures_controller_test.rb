# frozen_string_literal: true

require "test_helper"

class ProceduresControllerTest < ActionController::TestCase
  tests ProceduresController

  def setup
    setup_controller_test
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

  # Tests for GET actions with type search and valid id
  test "should get actions search with valid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "search", id: procedure.id }
    assert_response :success
    assert_match(/Ricerca su board/, @response.body)
  end

  # Tests for GET actions with type search and invalid id
  test "should get actions search with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "search", id: 9999 }
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

  # Tests for GET actions with type edit-status and valid id
  test "should get actions edit-status with valid id" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    get :actions, params: { type: "edit-status", id: procedure.id, status_id: status.id }
    assert_response :success
    assert_match(/Modifica stato/, @response.body)
  end

  # Tests for GET actions with type edit-status and invalid id
  test "should get actions edit-status with invalid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "edit-status", id: procedure.id, status_id: 9999 }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Tests for GET actions with type remove-status and valid id
  test "should get actions remove-status with valid id" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    get :actions, params: { type: "remove-status", id: procedure.id, status_id: status.id }
    assert_response :success
    assert_match(/Rimuovi stato/, @response.body)
  end

  # Tests for GET actions with type remove-status and invalid id
  test "should get actions remove-status with invalid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "remove-status", id: procedure.id, status_id: 9999 }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Tests for GET actions with type add-item and valid id
  test "should get actions add-item with valid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "add-item", id: procedure.id }
    assert_response :success
    assert_match(/Aggiungi #{procedure.resources_item_string}/, @response.body)
  end

  # Tests for GET actions with type add-item and invalid id
  test "should get actions add-item with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "add-item", id: 9999 }
    end
  end

  # Tests for GET actions with type add-item-existing and valid id
  test "should get actions add-item-existing with valid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "add-item-existing", id: procedure.id }
    assert_response :success
    assert_match(/Aggiungi #{procedure.resources_item_string}/, @response.body)
  end

  # Tests for GET actions with type add-item-existing and invalid id
  test "should get actions add-item-existing with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "add-item-existing", id: 9999 }
    end
  end

  # Tests for GET actions with type edit-item and valid id
  test "should get actions edit-item with valid id" do
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    get :actions, params: { type: "edit-item", id: procedure.id, item_id: item.id }
    assert_response :success
    assert_match(/Modifica #{procedure.resources_item_string}/, @response.body)
  end

  # Tests for GET actions with type edit-item and invalid id
  test "should get actions edit-item with invalid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "edit-item", id: procedure.id, item_id: 9999 }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Tests for GET actions with type remove-item and valid id
  test "should get actions remove-item with valid id" do
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    get :actions, params: { type: "remove-item", id: procedure.id, item_id: item.id }
    assert_response :success
    assert_match(/Rimuovi #{procedure.resources_item_string}/, @response.body)
  end

  # Tests for GET actions with type remove-item and invalid id
  test "should get actions remove-item with invalid id" do
    procedure = procedures(:one)
    get :actions, params: { type: "remove-item", id: procedure.id, item_id: 9999 }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Test for GET actions con tipo non valido
  test "should get actions with invalid type" do
    get :actions, params: { type: "invalid_type" }
    assert_response :success
    assert_match(/Si è verificato un errore/, @response.body)
  end

  # Tests for POST toggle_show_archived_projects_action with valid id and valid policy
  test "should post toggle_show_archived_projects_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :toggle_show_archived_projects_action, params: { id: procedure.id }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Tests for POST create_action with valid policy
  test "should post create_action with valid policy" do
    @user.users_policies.create!(policy: "procedures_create")
    post :create_action, params: { name: "New Procedure", description: "Description of new procedure", resources_type: "tasks" }
    assert_response :success
    assert_match(/Board creata/, @response.body)
  end

  # Tests for POST create_action without valid policy
  test "should not post create_action without valid policy" do
    post :create_action, params: { name: "New Procedure", description: "Description of new procedure", resources_type: "tasks" }
    assert_redirected_to root_path
  end

  # Tests for POST create_action with missing parameters
  test "should not post create_action with missing parameters" do
    @user.users_policies.create!(policy: "procedures_create")
    post :create_action, params: { name: "", description: "Description of new procedure", resources_type: "tasks" }
    assert_response :success
    assert_match(/Nuova board/, @response.body)
  end

  # Tests for POST edit_action with valid id and valid policy
  test "should post edit_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :edit_action, params: { id: procedure.id, name: "Updated Name", description: "Updated Description", resources_type: "projects" }
    assert_response :success
    assert_match(/Board aggiornata/, @response.body)
  end

  # Tests for POST edit_action without valid policy
  test "should not post edit_action without valid policy" do
    procedure = procedures(:one)
    post :edit_action, params: { id: procedure.id, name: "Updated Name", description: "Updated Description", resources_type: "projects" }
    assert_redirected_to root_path
  end

  # Tests for POST edit_action with invalid id
  test "should not post edit_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_edit")
    post :edit_action, params: { id: 9999, name: "Updated Name", description: "Updated Description", resources_type: "projects" }
    assert_redirected_to procedures_path
  end

  # Tests for POST edit_action with missing parameters
  test "should not post edit_action with missing parameters" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :edit_action, params: { id: procedure.id, name: "", description: "Updated Description", resources_type: "projects" }
    assert_response :success
    assert_match(/Modifica board/, @response.body)
  end

  # Tests for POST archive_action with valid id and valid policy
  test "should post archive_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_archive")
    procedure = procedures(:one)
    post :archive_action, params: { id: procedure.id }
    assert_response :success
    assert_match(/Board archiviata/, @response.body)
  end

  # Tests for POST archive_action without valid policy
  test "should not post archive_action without valid policy" do
    procedure = procedures(:one)
    post :archive_action, params: { id: procedure.id }
    assert_redirected_to root_path
  end

  # Tests for POST archive_action with invalid id
  test "should not post archive_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_archive")
    post :archive_action, params: { id: 9999 }
    assert_redirected_to procedures_path
  end

  # Tests for POST unarchive_action with valid id and valid policy
  test "should post unarchive_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_unarchive")
    procedure = procedures(:one)
    post :unarchive_action, params: { id: procedure.id }
    assert_response :success
    assert_match(/Board ri-attivata/, @response.body)
  end

  # Tests for POST unarchive_action without valid policy
  test "should not post unarchive_action without valid policy" do
    procedure = procedures(:one)
    post :unarchive_action, params: { id: procedure.id }
    assert_redirected_to root_path
  end

  # Tests for POST unarchive_action with invalid id
  test "should not post unarchive_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_unarchive")
    post :unarchive_action, params: { id: 9999 }
    assert_redirected_to procedures_path
  end

  # Tests for POST clone_action with valid id and valid policy
  test "should post clone_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_clone")
    procedure = procedures(:one)
    post :clone_action, params: { id: procedure.id, name: "Cloned Procedure" }
    assert_response :success
    assert_match(/Board clonata/, @response.body)
  end

  # Tests for POST clone_action without valid policy
  test "should not post clone_action without valid policy" do
    procedure = procedures(:one)
    post :clone_action, params: { id: procedure.id, name: "Cloned Procedure" }
    assert_redirected_to root_path
  end

  # Tests for POST clone_action with invalid id
  test "should not post clone_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_clone")
    post :clone_action, params: { id: 9999, name: "Cloned Procedure" }
    assert_redirected_to procedures_path
  end

  # Tests for POST destroy_action with valid id and valid policy
  test "should post destroy_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_destroy")
    procedure = procedures(:one)
    post :destroy_action, params: { id: procedure.id }
    assert_response :success
    assert_match(/Board eliminata/, @response.body)
  end

  # Tests for POST destroy_action without valid policy
  test "should not post destroy_action without valid policy" do
    procedure = procedures(:one)
    post :destroy_action, params: { id: procedure.id }
    assert_redirected_to root_path
  end

  # Tests for POST destroy_action with invalid id
  test "should not post destroy_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_destroy")
    post :destroy_action, params: { id: 9999 }
    assert_redirected_to procedures_path
  end

  # Tests for POST add_status_action with valid id and valid policy
  test "should post add_status_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :add_status_action, params: { id: procedure.id, title: "New Status" }
    assert_response :success
    assert_match(/Stato aggiunto/, @response.body)
  end

  # Tests for POST add_status_action without valid policy
  test "should not post add_status_action without valid policy" do
    procedure = procedures(:one)
    post :add_status_action, params: { id: procedure.id, title: "New Status" }
    assert_redirected_to root_path
  end

  # Tests for POST add_status_action with invalid id
  test "should not post add_status_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_edit")
    post :add_status_action, params: { id: 9999, title: "New Status" }
    assert_redirected_to procedures_path
  end

  # Tests for POST edit_status_action with valid id and valid policy
  test "should post edit_status_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    post :edit_status_action, params: { id: procedure.id, status_id: status.id, title: "Updated Status" }
    assert_response :success
    assert_match(/Stato modificato/, @response.body)
  end

  # Tests for POST edit_status_action without valid policy
  test "should not post edit_status_action without valid policy" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    post :edit_status_action, params: { id: procedure.id, status_id: status.id, title: "Updated Status" }
    assert_redirected_to root_path
  end

  # Tests for POST edit_status_action with invalid id
  test "should not post edit_status_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_edit")
    post :edit_status_action, params: { id: 9999, status_id: 1, title: "Updated Status" }
    assert_redirected_to procedures_path
  end

  # Tests for POST edit_status_action with invalid status_id
  test "should not post edit_status_action with invalid status_id" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :edit_status_action, params: { id: procedure.id, status_id: 9999, title: "Updated Status" }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Tests for POST remove_status_action with valid id and valid policy
  test "should post remove_status_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    post :remove_status_action, params: { id: procedure.id, status_id: status.id }
    assert_response :success
    assert_match(/Stato rimosso/, @response.body)
  end

  # Tests for POST remove_status_action without valid policy
  test "should not post remove_status_action without valid policy" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    post :remove_status_action, params: { id: procedure.id, status_id: status.id }
    assert_redirected_to root_path
  end

  # Tests for POST remove_status_action with invalid id
  test "should not post remove_status_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_edit")
    post :remove_status_action, params: { id: 9999, status_id: 1 }
    assert_redirected_to procedures_path
  end

  # Tests for POST remove_status_action with invalid status_id
  test "should not post remove_status_action with invalid status_id" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :remove_status_action, params: { id: procedure.id, status_id: 9999 }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Tests for POST move_status_action with valid id and valid policy
  test "should post move_status_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    post :move_status_action, params: { id: procedure.id, status_id: status.id, direction: "up" }
    assert_response :success
  end

  # Tests for POST move_status_action without valid policy
  test "should not post move_status_action without valid policy" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    post :move_status_action, params: { id: procedure.id, status_id: status.id, direction: "up" }
    assert_redirected_to root_path
  end

  # Tests for POST move_status_action with invalid id
  test "should not post move_status_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_edit")
    post :move_status_action, params: { id: 9999, status_id: 1, direction: "up" }
    assert_redirected_to procedures_path
  end

  # Tests for POST move_status_action with invalid status_id
  test "should not post move_status_action with invalid status_id" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :move_status_action, params: { id: procedure.id, status_id: 9999, direction: "up" }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Tests for POST add_item_action with valid id and valid policy
  test "should post add_item_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :add_item_action, params: { id: procedure.id, title: "New Item", description: "Description of new item", status_id: procedure.procedures_statuses.first.id }
    assert_response :success
    assert_match(/#{procedure.resources_item_string.capitalize} aggiunto/, @response.body)
  end

  # Tests for POST add_item_action without valid policy
  test "should not post add_item_action without valid policy" do
    procedure = procedures(:one)
    post :add_item_action, params: { id: procedure.id, title: "New Item", description: "Description of new item", status_id: procedure.procedures_statuses.first.id }
    assert_redirected_to root_path
  end

  # Tests for POST add_item_action with invalid id
  test "should not post add_item_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_edit")
    post :add_item_action, params: { id: 9999, title: "New Item", description: "Description of new item", status_id: 1 }
    assert_redirected_to procedures_path
  end

  # Tests for POST add_item_action with missing parameters
  test "should not post add_item_action with missing parameters" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :add_item_action, params: { id: procedure.id, title: "", description: "Description of new item", status_id: procedure.procedures_statuses.first.id }
    assert_response :success
    assert_match(/Aggiungi #{procedure.resources_item_string}/, @response.body)
  end

  # Tests for POST edit_item_action with valid id and valid policy
  test "should post edit_item_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    post :edit_item_action, params: { id: procedure.id, item_id: item.id, title: "Updated Item", description: "Updated Description", status_id: procedure.procedures_statuses.last.id }
    assert_response :success
    assert_match(/#{procedure.resources_item_string.capitalize} modificato/, @response.body)
  end

  # Tests for POST edit_item_action without valid policy
  test "should not post edit_item_action without valid policy" do
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    post :edit_item_action, params: { id: procedure.id, item_id: item.id, title: "Updated Item", description: "Updated Description", status_id: procedure.procedures_statuses.last.id }
    assert_redirected_to root_path
  end

  # Tests for POST edit_item_action with invalid id
  test "should not post edit_item_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_edit")
    post :edit_item_action, params: { id: 9999, item_id: 1, title: "Updated Item", description: "Updated Description", status_id: 1 }
    assert_redirected_to procedures_path
  end

  # Tests for POST edit_item_action with invalid item_id
  test "should not post edit_item_action with invalid item_id" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :edit_item_action, params: { id: procedure.id, item_id: 9999, title: "Updated Item", description: "Updated Description", status_id: procedure.procedures_statuses.last.id }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Tests for POST remove_item_action with valid id and valid policy
  test "should post remove_item_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    post :remove_item_action, params: { id: procedure.id, item_id: item.id }
    assert_response :success
    assert_match(/#{procedure.resources_item_string.capitalize} rimosso/, @response.body)
  end

  # Tests for POST remove_item_action without valid policy
  test "should not post remove_item_action without valid policy" do
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    post :remove_item_action, params: { id: procedure.id, item_id: item.id }
    assert_redirected_to root_path
  end

  # Tests for POST remove_item_action with invalid id
  test "should not post remove_item_action with invalid id" do
    @user.users_policies.create!(policy: "procedures_edit")
    post :remove_item_action, params: { id: 9999, item_id: 1 }
    assert_redirected_to procedures_path
  end

  # Tests for POST remove_item_action with invalid item_id
  test "should not post remove_item_action with invalid item_id" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    post :remove_item_action, params: { id: procedure.id, item_id: 9999 }
    assert_redirected_to procedures_show_path(procedure)
  end

  # Tests for POST move_item_action with valid id and valid policy
  test "should post move_item_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    post :move_item_action, params: { id: procedure.id, item_id: item.id, direction: "up" }
    assert_response :success
  end
end
