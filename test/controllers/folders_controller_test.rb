# frozen_string_literal: true

require "test_helper"

class FoldersControllerTest < ActionController::TestCase
  tests FoldersController

  def setup
    setup_controller_test
  end

  test "actions" do
    folder = folders(:one)
    matilda_controller_action("create", "Nuova cartella")
    matilda_controller_action("edit", "Modifica cartella", folder.id)
    matilda_controller_action("destroy", "Elimina cartella", folder.id)
    matilda_controller_action_invalid
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
