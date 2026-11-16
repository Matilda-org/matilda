# frozen_string_literal: true

require "test_helper"

class ContactsControllerTest < ActionController::TestCase
  tests ContactsController

  def setup
    setup_controller_test
  end

  test "actions" do
    grant_policy("crm")
    contact = contacts(:one)
    project = projects(:one).tap { |p| p.update!(contact: contact) }

    matilda_controller_action("create", "Nuovo contatto")
    matilda_controller_action("edit", "Modifica contatto", contact.id)
    matilda_controller_action("archive", "Archivia contatto", contact.id)
    matilda_controller_action("unarchive", "Ri-attiva contatto", contact.id)
    matilda_controller_action("destroy", "Elimina contatto", contact.id)
    matilda_controller_action("link-project", "Collega progetto", contact.id)
    matilda_controller_action("unlink-project", "Scollega progetto", contact.id, { project_id: project.id })

    matilda_controller_action_invalid
  end

  test "create form offers AI filling when the assistant is configured" do
    grant_policy("crm")
    Setting.set("vectorsearch_openai_key", "sk-test")

    get :actions, params: { type: "create" }

    assert_response :success
    assert_includes @response.body, "Compila con l'assistente"
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "crm"
    )
  end

  test "show" do
    contact = contacts(:one)
    matilda_controller_endpoint(:get, :show,
      params: { id: contact.id },
      policy: "crm"
    )
  end

  test "create_action" do
    matilda_controller_endpoint(:post, :create_action,
      params: { name: "Test Contact", email: "test@contact.com" },
      policy: "crm",
      title: "Nuovo contatto",
      feedback: "Contatto creato"
    )

    assert_not_nil Contact.find_by(name: "Test Contact")
  end

  test "create_action with invalid data marks the name" do
    grant_policy("crm")
    post :create_action, params: { name: "" }

    assert_response :success
    assert_select "input#name.is-invalid + .invalid-feedback"
    assert_select "input#email:not(.is-invalid)"
  end

  test "edit_action" do
    contact = contacts(:one)
    matilda_controller_endpoint(:post, :edit_action,
      params: { id: contact.id, name: "Updated Contact" },
      policy: "crm",
      title: "Modifica contatto",
      feedback: "Contatto aggiornato"
    )

    assert_equal "Updated Contact", contact.reload.name
  end

  test "destroy_action" do
    contact = contacts(:one)
    matilda_controller_endpoint(:post, :destroy_action,
      params: { id: contact.id },
      policy: "crm",
      title: "Elimina contatto",
      feedback: "Contatto eliminato"
    )

    assert_not Contact.exists?(contact.id)
  end

  test "archive_action and unarchive_action" do
    contact = contacts(:one)

    matilda_controller_endpoint(:post, :archive_action,
      params: { id: contact.id },
      policy: "crm",
      title: "Archivia contatto",
      feedback: "Contatto archiviato"
    )
    assert contact.reload.archived

    matilda_controller_endpoint(:post, :unarchive_action,
      params: { id: contact.id },
      policy: "crm",
      title: "Ri-attiva contatto",
      feedback: "Contatto ri-attivato"
    )
    assert_not contact.reload.archived
  end

  test "link_project_action and unlink_project_action" do
    contact = contacts(:one)
    project = projects(:one)

    matilda_controller_endpoint(:post, :link_project_action,
      params: { id: contact.id, project_id: project.id },
      policy: "crm",
      title: "Collega progetto",
      feedback: "Progetto collegato"
    )
    assert_equal contact.id, project.reload.contact_id

    matilda_controller_endpoint(:post, :unlink_project_action,
      params: { id: contact.id, project_id: project.id },
      policy: "crm",
      title: "Scollega progetto",
      feedback: "Progetto scollegato"
    )
    assert_nil project.reload.contact_id
  end

  # BULK ACTIONS
  ##############################################################################

  test "bulk_action archives contacts and the undo restores them" do
    grant_policy("crm")
    one = contacts(:one)
    two = Contact.create!(name: "Contact Two")

    post :bulk_action, params: { operation: "archive", ids: [ one.id, two.id, 99_999 ] }

    assert_response :success
    assert_includes @response.body, "<h3 class=\"fs-5 mb-1\">2 contatti archiviati</h3>"
    assert one.reload.archived
    assert two.reload.archived

    # Replay the undo the feedback offers
    undo_href = CGI.unescapeHTML(@response.body[%r{action="([^"]*bulk-action[^"]*)"}, 1])
    undo_params = Rack::Utils.parse_nested_query(URI.parse(undo_href).query)
    assert_equal "unarchive", undo_params["operation"]

    post :bulk_action, params: undo_params

    assert_response :success
    assert_includes @response.body, "2 contatti ripristinati"
    assert_not one.reload.archived
    assert_not two.reload.archived
    assert_not_includes @response.body, "operation=archive"
  end

  test "bulk_action only touches contacts not already in the target state" do
    grant_policy("crm")
    one = contacts(:one)
    archived = Contact.create!(name: "Archived", archived: true)

    post :bulk_action, params: { operation: "archive", ids: [ one.id, archived.id ] }

    assert_includes @response.body, "1 contatto archiviato"
    assert_includes @response.body, "ids%5B%5D=#{one.id}"
    assert_not_includes @response.body, "ids%5B%5D=#{archived.id}"
  end

  test "bulk_action requires the crm policy and a known operation" do
    contact = contacts(:one)

    post :bulk_action, params: { operation: "archive", ids: [ contact.id ] }
    assert_redirected_to root_path
    assert_not contact.reload.archived

    grant_policy("crm")
    Rails.cache.clear
    post :bulk_action, params: { operation: "destroy", ids: [ contact.id ] }
    assert_includes @response.body, "id=\"action-modal-title\">Errore</h3>"
    assert Contact.exists?(contact.id)
  end

  test "index renders the selection mode without the folder action" do
    grant_policy("crm")

    get :index

    assert_response :success
    assert_includes @response.body, "data-controller=\"bulk-select\""
    assert_includes @response.body, "aria-label=\"Seleziona #{contacts(:one).name}\""
    assert_not_includes @response.body, "Sposta in cartella"
  end

  test "bulk-archive asks for confirmation before archiving contacts" do
    grant_policy("crm")
    contact = contacts(:one)

    get :actions, params: { type: "bulk-archive", ids: [ contact.id ] }

    assert_response :success
    assert_includes @response.body, "id=\"action-modal-title\">Archivia contatti</h3>"
    assert_includes @response.body, "1 contatto verrà archiviato"
    assert_select "form[action='#{contacts_bulk_action_path}'] input[name=operation][value=archive]"
    assert_select "input[type=hidden][name='ids[]'][value='#{contact.id}']"
    assert_not contact.reload.archived
  end
end
