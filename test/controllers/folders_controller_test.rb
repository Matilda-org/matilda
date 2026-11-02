# frozen_string_literal: true

require "test_helper"

class FoldersControllerTest < ActionController::TestCase
  tests FoldersController

  def setup
    setup_controller_test
  end

  test "actions" do
    grant_policy("folders_create", "folders_edit", "folders_destroy", "folders_manage_resources")
    folder = folders(:one)
    matilda_controller_action("create", "Nuova cartella")
    matilda_controller_action("edit", "Modifica cartella", folder.id)
    matilda_controller_action("destroy", "Elimina cartella", folder.id)
    matilda_controller_action_invalid
  end

  def card_title(name)
    %(<h5 class="card-title">#{name}</h5>)
  end

  test "index lists full and empty folders, counting only active projects the user can see" do
    grant_policy("projects_index", "credentials_index")
    full = Folder.create!(name: "Piena")
    Folder.create!(name: "Vuota")
    full.folders_items.create!(resource: Project.create!(code: "ACT", name: "Active", year: 2026))
    full.folders_items.create!(resource: Project.create!(code: "ARC", name: "Archived", year: 2026, archived: true))

    get :index
    assert_response :success
    assert_includes @response.body, card_title("Piena")
    assert_includes @response.body, card_title("Vuota")
    assert_includes @response.body, "1 progetto attivo"

    get :index, params: { filters: "empty" }
    assert_not_includes @response.body, card_title("Piena")
    assert_includes @response.body, card_title("Vuota")

    get :index, params: { filters: "full", search: "pie" }
    assert_includes @response.body, card_title("Piena")
    assert_not_includes @response.body, card_title("Vuota")
  end

  test "show" do
    matilda_controller_endpoint(:get, :show,
      params: { id: folders(:one).id }
    )
  end

  test "create_action" do
    matilda_controller_endpoint(:post, :create_action,
      params: { name: "New Folder" },
      policy: "folders_create",
      title: "Nuova cartella",
      feedback: "Cartella creata"
    )

    folder = Folder.find_by(name: "New Folder")
    assert_not_nil folder
  end

  test "edit_action" do
    folder = folders(:one)
    matilda_controller_endpoint(:post, :edit_action,
      params: { id: folder.id, name: "Updated Folder" },
      policy: "folders_edit",
      title: "Modifica cartella",
      feedback: "Cartella aggiornata"
    )

    folder.reload
    assert_equal "Updated Folder", folder.name
  end

  test "destroy_action" do
    folder = folders(:one)
    matilda_controller_endpoint(:post, :destroy_action,
      params: { id: folder.id },
      policy: "folders_destroy",
      title: "Elimina cartella",
      feedback: "Cartella eliminata"
    )

    assert_not Folder.exists?(folder.id)
  end

  test "manage_resource_action" do
    folder = folders(:one)
    project = projects(:one)
    matilda_controller_endpoint(:post, :manage_resource_action,
      params: { folder_id: folder.id, resource_type: "Project", resource_id: project.id },
      policy: "folders_manage_resources",
      title: "Gestisci cartella",
      feedback: "Cartella aggiornata"
    )

    folder.reload
    assert folder.projects.exists?(project.id)
  end
end
