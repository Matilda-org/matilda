# frozen_string_literal: true

require "test_helper"

class UsersControllerTest < ActionController::TestCase
  tests UsersController

  def setup
    setup_controller_test
  end

  test "actions" do
    grant_policy("users_show", "users_create")
    user = users(:one)

    matilda_controller_action("create", "Nuovo utente")
    matilda_controller_action("edit", "Modifica profilo", user.id)
    matilda_controller_action("edit-policies", "Modifica permessi", user.id)
    matilda_controller_action("destroy", "Elimina utente", user.id)

    matilda_controller_action_invalid
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "users_index"
    )
  end

  test "create_action" do
    matilda_controller_endpoint(:post, :create_action,
      params: { name: "Test", surname: "User", email: "create_test@example.com" },
      policy: "users_create",
      title: "Nuovo utente",
      feedback: "Utente creato"
    )

    assert_not_nil User.find_by(email: "create_test@example.com")
  end

  test "edit_action" do
    user = users(:one)

    matilda_controller_endpoint(:patch, :edit_action,
      params: { id: user.id, name: "Updated", surname: "User", email: "update_test@example.com", description: "A short bio" },
      policy: "users_edit",
      title: "Modifica profilo",
      feedback: "Profilo aggiornato"
    )

    user.reload
    assert_equal "Updated", user.name
    assert_equal "User", user.surname
    assert_equal "update_test@example.com", user.email
    assert_equal "A short bio", user.description
  end

  test "edit_policies_action" do
    user = users(:one)

    matilda_controller_endpoint(:patch, :edit_policies_action,
      params: { id: user.id, policies: [ "users_index", "users_edit" ] },
      policy: "users_edit_policies",
      title: "Modifica permessi",
      feedback: "Permessi utente aggiornati"
    )
  end

  test "destroy_action" do
    user = users(:two)

    matilda_controller_endpoint(:delete, :destroy_action,
      params: { id: user.id },
      policy: "users_destroy",
      title: "Elimina utente",
      feedback: "Utente eliminato"
    )

    assert_nil User.find_by(id: user.id)
  end

  test "dashboard groups assigned tasks by deadline and hides empty groups" do
    Task.create!(title: "Dash overdue", user: @user, deadline: Date.today - 2, accepted: true)
    Task.create!(title: "Dash upcoming", user: @user, project: projects(:one), deadline: Date.today + 2, accepted: true)
    Task.create!(title: "Dash no deadline", user: @user, accepted: true)

    get :show, params: { id: @user.id }

    assert_response :success
    assert_select "turbo-frame#module-tasks-assigned" do
      assert_select "section[aria-label='Scaduti']", text: /Dash overdue/
      assert_select "section[aria-label='Prossimi']", text: /Dash upcoming/
      assert_select "section[aria-label='Senza scadenza']", text: /Dash no deadline/
      assert_select "section[aria-label='Oggi']", count: 0
      assert_select "select[name='tasks_project_id'] option", text: projects(:one).name
    end
    assert_select "turbo-frame#module-tasks-followed"
  end
end
