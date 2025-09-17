# frozen_string_literal: true

require "test_helper"

class ProceduresControllerTest < ActionController::TestCase
  tests ProceduresController

  def setup
    setup_controller_test
  end

  test "actions" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    item = procedure.procedures_items.first
    matilda_controller_action("create", "Nuova board")
    matilda_controller_action("edit", "Modifica board", procedure.id)
    matilda_controller_action("archive", "Archivia board", procedure.id)
    matilda_controller_action("unarchive", "Ri-attiva board", procedure.id)
    matilda_controller_action("clone", "Clona board", procedure.id)
    matilda_controller_action("search", "Ricerca su board", procedure.id)
    matilda_controller_action("destroy", "Elimina board", procedure.id)
    matilda_controller_action("add-status", "Aggiungi stato", procedure.id)
    matilda_controller_action("edit-status", "Modifica stato", procedure.id, { status_id: status.id })
    matilda_controller_action("remove-status", "Rimuovi stato", procedure.id, { status_id: status.id })
    matilda_controller_action("add-item", "Aggiungi #{procedure.resources_item_string}", procedure.id)
    matilda_controller_action("add-item-existing", "Aggiungi #{procedure.resources_item_string}", procedure.id)
    matilda_controller_action("edit-item", "Modifica #{procedure.resources_item_string}", procedure.id, { item_id: item.id })
    matilda_controller_action("remove-item", "Rimuovi #{procedure.resources_item_string}", procedure.id, { item_id: item.id })

    matilda_controller_action_invalid
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "procedures_index"
    )
  end

  test "show" do
    procedure = procedures(:one)
    matilda_controller_endpoint(:get, :show,
      params: { id: procedure.id },
      policy: "procedures_show"
    )
  end

  test "toggle_show_archived_projects_action" do
    procedure = procedures(:one)
    matilda_controller_endpoint(:post, :toggle_show_archived_projects_action,
      params: { id: procedure.id },
      policy: "procedures_edit",
      redirect: procedures_show_path(procedure)
    )
  end

  test "create_action" do
    matilda_controller_endpoint(:post, :create_action,
      params: { name: "New Procedure", description: "Description of new procedure", resources_type: "tasks" },
      policy: "procedures_create",
      title: "Nuova board",
      feedback: "Board creata"
    )

    procedure = Procedure.find_by(name: "New Procedure")
    assert_not_nil procedure
    assert_equal "Description of new procedure", procedure.description
    assert_equal "tasks", procedure.resources_type
  end

  test "edit_action" do
    procedure = procedures(:one)
    matilda_controller_endpoint(:post, :edit_action,
      params: { id: procedure.id, name: "Updated Name", description: "Updated Description", resources_type: "projects" },
      policy: "procedures_edit",
      title: "Modifica board",
      feedback: "Board aggiornata"
    )

    procedure.reload
    assert_equal "Updated Name", procedure.name
    assert_equal "Updated Description", procedure.description
    assert_equal "projects", procedure.resources_type
  end

  test "archive_action" do
    procedure = procedures(:one)
    assert_not procedure.archived

    matilda_controller_endpoint(:post, :archive_action,
      params: { id: procedure.id },
      policy: "procedures_archive",
      title: "Archivia board",
      feedback: "Board archiviata"
    )

    procedure.reload
    assert procedure.archived?
  end

  test "unarchive_action" do
    procedure = procedures(:one)
    procedure.update(archived: true)
    assert procedure.archived

    matilda_controller_endpoint(:post, :unarchive_action,
      params: { id: procedure.id },
      policy: "procedures_unarchive",
      title: "Ri-attiva board",
      feedback: "Board ri-attivata"
    )

    procedure.reload
    assert_not procedure.archived
  end

  test "clone_action" do
    procedure = procedures(:one)
    matilda_controller_endpoint(:post, :clone_action,
      params: { id: procedure.id },
      policy: "procedures_clone",
      title: "Clona board",
      feedback: "Board clonata"
    )

    cloned_procedure = Procedure.find_by(name: "#{procedure.name} (clone)")
    assert_not_nil cloned_procedure
  end

  test "destroy_action" do
    procedure = procedures(:one)
    matilda_controller_endpoint(:post, :destroy_action,
      params: { id: procedure.id },
      policy: "procedures_destroy",
      title: "Elimina board",
      feedback: "Board eliminata",
      redirect: procedures_path
    )

    assert_not Procedure.exists?(procedure.id)
  end

  test "add_status_action" do
    procedure = procedures(:one)
    matilda_controller_endpoint(:post, :add_status_action,
      params: { id: procedure.id, title: "New Status" },
      policy: "procedures_edit",
      title: "Aggiungi stato",
      feedback: "Stato aggiunto"
    )

    new_status = procedure.procedures_statuses.find_by(title: "New Status")
    assert_not_nil new_status
  end

  test "edit_status_action" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    matilda_controller_endpoint(:post, :edit_status_action,
      params: { id: procedure.id, status_id: status.id, title: "Updated Status" },
      policy: "procedures_edit",
      title: "Modifica stato",
      feedback: "Stato modificato"
    )

    status.reload
    assert_equal "Updated Status", status.title
  end

  test "remove_status_action" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    matilda_controller_endpoint(:post, :remove_status_action,
      params: { id: procedure.id, status_id: status.id },
      policy: "procedures_edit",
      title: "Rimuovi stato",
      feedback: "Stato rimosso"
    )

    assert_not procedure.procedures_statuses.exists?(status.id)
  end

  test "move_status_action" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    matilda_controller_endpoint(:post, :move_status_action,
      params: { id: procedure.id, status_id: status.id, direction: "up" },
      policy: "procedures_edit",
    )
  end

  test "add_item_action" do
    procedure = procedures(:one)
    matilda_controller_endpoint(:post, :add_item_action,
      params: { id: procedure.id, title: "New Item", status_id: procedure.procedures_statuses.first.id },
      policy: "procedures_edit",
      title: "Aggiungi #{procedure.resources_item_string}",
      feedback: "#{procedure.resources_item_string.capitalize} aggiunto"
    )

    new_item = procedure.procedures_items.find_by(title: "New Item")
    assert_not_nil new_item
  end

  test "edit_item_action" do
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    matilda_controller_endpoint(:post, :edit_item_action,
      params: { id: procedure.id, item_id: item.id, title: "Updated Item" },
      policy: "procedures_edit",
      title: "Modifica #{procedure.resources_item_string}",
      feedback: "#{procedure.resources_item_string.capitalize} modificato"
    )

    item.reload
    assert_equal "Updated Item", item.title
  end

  test "remove_item_action" do
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    matilda_controller_endpoint(:post, :remove_item_action,
      params: { id: procedure.id, item_id: item.id },
      policy: "procedures_edit",
      title: "Rimuovi #{procedure.resources_item_string}",
      feedback: "#{procedure.resources_item_string.capitalize} rimosso"
    )

    assert_not procedure.procedures_items.exists?(item.id)
  end

  test "move_item_action" do
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    matilda_controller_endpoint(:post, :move_item_action,
      params: { id: procedure.id, item_id: item.id, direction: "up" },
      policy: "procedures_edit",
    )
  end
end
