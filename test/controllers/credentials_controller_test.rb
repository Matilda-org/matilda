# frozen_string_literal: true

require "test_helper"

class CredentialsControllerTest < ActionController::TestCase
  tests CredentialsController

  def setup
    setup_controller_test
  end

  test "actions" do
    credential = credentials(:one)
    matilda_controller_action("create", "Nuova credenziale")
    matilda_controller_action("edit", "Modifica credenziale", credential.id)
    matilda_controller_action("destroy", "Elimina credenziale", credential.id)
    matilda_controller_action("show", "Visualizza credenziale", credential.id)
    matilda_controller_action_invalid
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "credentials_index"
    )
  end

  test "set_phrase_action" do
    matilda_controller_endpoint(:post, :set_phrase_action,
      params: { phrase: { phrase: "new_passphrase" } },
      policy: "credentials_set_phrase",
      title: "Password di criptazione",
      feedback: "Password di criptazione impostata"
    )
  end

  test "create_action" do
    matilda_controller_endpoint(:post, :create_action,
      params: { name: "New Credential", secure_username: "new_user", secure_password: "new_pass", secure_content: "new_content" },
      policy: "credentials_create",
      title: "Nuova credenziale",
      feedback: "Credenziale salvata"
    )

    credential = Credential.find_by(name: "New Credential")
    assert_not_nil credential
    assert_equal "new_user", credential.secure_username
    assert_equal "new_pass", credential.secure_password
    assert_equal "new_content", credential.secure_content
  end

  test "edit_action" do
    credential = credentials(:one)
    matilda_controller_endpoint(:post, :edit_action,
      params: { id: credential.id, name: "Updated Credential", secure_username: "updated_user", secure_password: "updated_pass", secure_content: "updated_content" },
      policy: "credentials_edit",
      title: "Modifica credenziale",
      feedback: "Credenziale salvata"
    )

    credential.reload
    assert_equal "Updated Credential", credential.name
    assert_equal "updated_user", credential.secure_username
    assert_equal "updated_pass", credential.secure_password
    assert_equal "updated_content", credential.secure_content
  end

  test "destroy_action" do
    credential = credentials(:one)
    matilda_controller_endpoint(:post, :destroy_action,
      params: { id: credential.id },
      policy: "credentials_destroy",
      title: "Elimina credenziale",
      feedback: "Credenziale eliminata",
    )

    assert_not Credential.exists?(credential.id)
  end
end
