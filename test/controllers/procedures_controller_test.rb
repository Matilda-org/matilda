# frozen_string_literal: true

require "test_helper"

class ProceduresControllerTest < ActionController::TestCase
  tests ProceduresController

  def setup
    setup_controller_test
  end

  test "actions" do
    grant_policy("procedures_show")
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

  test "duplicate_status_action" do
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first
    assert_difference -> { procedure.procedures_statuses.count }, 1 do
      matilda_controller_endpoint(:post, :duplicate_status_action,
        params: { id: procedure.id, status_id: status.id },
        policy: "procedures_edit"
      )
    end
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
      params: { id: procedure.id, item_id: item.id, procedures_status_id: item.procedures_status_id, order: 1 },
      policy: "procedures_edit",
    )
  end

  test "move_item_action reverts on an invalid target status" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    original_status_id = item.procedures_status_id

    post :move_item_action, params: { id: procedure.id, item_id: item.id, procedures_status_id: 0, order: 1 }

    assert_response :unprocessable_content
    assert_equal original_status_id, item.reload.procedures_status_id
  end

  test "show renders column counts and the card move menu" do
    @user.users_policies.create!(policy: "procedures_show")
    procedure = procedures(:one)
    source = procedure.procedures_statuses.first
    target = procedure.procedures_statuses.create!(title: "Target status")
    # Task boards only show items backed by a task
    item = procedure.procedures_items.create!(procedures_status: source, title: "With task", resource: tasks(:one), order: 1)

    get :show, params: { id: procedure.id }

    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(source, "kanban-status")} .badge", text: "1"
    assert_select "##{ActionView::RecordIdentifier.dom_id(target, "kanban-status")} .badge", text: "0"
    assert_select "form[action='#{procedures_move_item_action_path(id: procedure.id, item_id: item.id)}'] input[name='procedures_status_id'][value='#{target.id}']"
    assert_select "form[action='#{procedures_move_item_action_path(id: procedure.id, item_id: item.id)}'] input[name='procedures_status_id'][value='#{source.id}']", count: 0
    assert_select "form[action='#{procedures_quick_add_item_action_path(id: procedure.id)}'] input[name='procedures_status_id'][value='#{target.id}']"
  end

  test "move_item_action from the card menu appends to the target and re-renders both columns" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    source = item.procedures_status
    target = procedure.procedures_statuses.create!(title: "Target status")
    existing = procedure.procedures_items.create!(procedures_status: target, title: "Existing", order: 1)

    post :move_item_action, params: { id: procedure.id, item_id: item.id, procedures_status_id: target.id, render_columns: 1 }, format: :turbo_stream

    assert_response :success
    item.reload
    assert_equal target.id, item.procedures_status_id
    assert_equal 2, item.order
    assert_equal 1, existing.reload.order
    assert_includes response.body, %(target="#{ActionView::RecordIdentifier.dom_id(source, "kanban-status")}")
    assert_includes response.body, %(target="#{ActionView::RecordIdentifier.dom_id(target, "kanban-status")}")
  end

  test "move_item_action from drag and drop answers with an empty stream" do
    @user.users_policies.create!(policy: "procedures_edit")
    procedure = procedures(:one)
    item = procedure.procedures_items.first
    target = procedure.procedures_statuses.create!(title: "Target status")

    post :move_item_action, params: { id: procedure.id, item_id: item.id, procedures_status_id: target.id, order: 1 }, format: :turbo_stream

    assert_response :success
    assert_equal target.id, item.reload.procedures_status_id
    assert_not_includes response.body, "kanban-status"
  end

  test "quick_add_item_action creates a task in the column status and re-renders it" do
    grant_policy("procedures_show", "tasks_create")
    procedure = procedures(:one)
    procedure.update!(project: projects(:one))
    target = procedure.procedures_statuses.create!(title: "Target status")

    assert_difference -> { Task.count } => 1, -> { target.procedures_items.count } => 1 do
      post :quick_add_item_action, params: { id: procedure.id, procedures_status_id: target.id, title: "  Quick task  " }, format: :turbo_stream
    end

    assert_response :success
    task = Task.order(:id).last
    assert_equal "Quick task", task.title
    assert_equal Date.today, task.deadline
    assert_equal @user.id, task.user_id
    assert_equal projects(:one).id, task.project_id
    assert_includes response.body, %(target="#{ActionView::RecordIdentifier.dom_id(target, "kanban-status")}")
  end

  test "quick_add_item_action is denied without the tasks_create policy" do
    grant_policy("procedures_show")
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first

    assert_no_difference -> { Task.count } do
      post :quick_add_item_action, params: { id: procedure.id, procedures_status_id: status.id, title: "Quick task" }, format: :turbo_stream
    end

    assert_controller_invalid_policy
  end

  test "quick_add_item_action keeps the column on an invalid title" do
    grant_policy("procedures_show", "tasks_create")
    procedure = procedures(:one)
    status = procedure.procedures_statuses.first

    assert_no_difference -> { Task.count } do
      post :quick_add_item_action, params: { id: procedure.id, procedures_status_id: status.id, title: " " }, format: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_not_includes response.body, "kanban-status"
  end

  test "quick_add_item_action refuses model boards" do
    grant_policy("procedures_show", "tasks_create")
    procedure = procedures(:two)

    post :quick_add_item_action, params: { id: procedure.id, procedures_status_id: procedure.procedures_statuses.first.id, title: "Quick task" }, format: :turbo_stream

    assert_response :unprocessable_content
  end

  test "add-item modal is prefilled with the quick add title" do
    grant_policy("procedures_show")
    procedure = procedures(:one)

    get :actions, params: { type: "add-item", id: procedure.id, procedures_status_id: procedure.procedures_statuses.first.id, title: "Typed title" }

    assert_response :success
    assert_select "input[name=title][value=?]", "Typed title"
  end
end
