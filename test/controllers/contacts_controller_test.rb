# frozen_string_literal: true

require "test_helper"

class ContactsControllerTest < ActionController::TestCase
  tests ContactsController

  def setup
    setup_controller_test
  end

  test "actions" do
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
end
